#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'net/http'
require 'cgi'
require 'openssl'
require 'psych'

require_relative '../../ruby_task_helper/files/task_helper.rb' unless Object.const_defined?('TaskHelper')
require_relative '../../ruby_plugin_helper/lib/plugin_helper.rb' unless Object.const_defined?('RubyPluginHelper')

# bolt resolver plugin
class IncusInventory < TaskHelper
  include RubyPluginHelper

  # validation error
  class ValidationError < TaskHelper::Error
    def initialize(msg, details = nil)
      super(msg, 'bolt-plugin/validation-error', details)
    end
  end

  # rest api error
  class RestError < TaskHelper::Error
    def initialize(msg, details = nil)
      msg = '%d: %s' % [msg['error_code'], msg['error']]
      super(msg, 'bolt-plugin/runtime-error', details)
    end
  end

  attr_accessor :template

  def initialize
    super

    @http_options = {
      use_ssl: true,
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
    }
  end

  def client
    @client ||= Net::HTTP.start(@remote.host, @remote.port, @http_options)
  end

  def request(path, params = {})
    resp = client.request Net::HTTP::Get.new "/1.0/#{path}?#{URI.encode_www_form(params)}"
    message = JSON.parse(resp.body)
    raise RestError, message if message['error_code'] > 0 || message['metadata'].nil?
    message['metadata']
  end

  def mask(n)
    [ ((1 << 32) - 1) << (32 - n) ].pack('N').bytes.join('.')
  end

  def resolve_reference(opts)
    @template = opts.delete(:target_mapping) || {}
    unless template.key?(:uri) || template.key?(:name)
      raise ValidationError, "'name' or 'uri' must be set in 'target_mapping'"
    end

    possible_providers = ['incus', 'lxd'].select { |p| p == opts[:provider] || opts[:provider].nil? }
    conf_dir = possible_providers.filter_map { |provider|
      dir = ENV["#{provider.upcase}_CONF"] || File.join(File.expand_path('~/.config'), provider)
      dir if File.exist?(dir)
    }.first

    raise ValidationError, 'unable to find provider config directory' unless conf_dir

    @client_config = Psych.safe_load(File.read(File.join(conf_dir, 'config.yml')), aliases: true, symbolize_names: true)

    opts[:remote] ||= @client_config[:'default-remote']
    opts[:remote] = opts[:remote].to_sym

    raise ValidationError, "remote '#{opts[:remote]}' not in client configuration" unless @client_config[:remotes][opts[:remote]]

    remote = @client_config[:remotes][opts[:remote]]
    @remote = URI.parse(remote[:addr])

    @http_options[:cert] = OpenSSL::X509::Certificate.new(File.read(File.join(conf_dir, 'client.crt')))
    @http_options[:key] = OpenSSL::PKey::EC.new(File.read(File.join(conf_dir, 'client.key')))

    # Retrieve a instances
    params = { recursion: 2 }
    params[:filter] = opts[:filter] if opts[:filter]
    params[:project] = opts[:project] if opts[:project]
    params[:'all-projects'] = opts[:all_projects] unless opts[:project]

    resources = request('instances', params)

    # Select running instances
    resources.select! do |value|
      value['status'] == 'Running'
    end

    # Retrieve node configuration
    targets = resources.map do |res|
      i = 0
      res['state']['network']&.transform_keys! do |nic|
        if nic.start_with?('lo')
          nic
        else
          i += 1
          "nic#{i - 1}"
        end
      end
      res
    end

    attributes = required_data(template)
    target_data = targets.map do |target|
      attributes.each_with_object({}) do |attr, acc|
        attr = attr.first
        acc[attr] = target.key?(attr) ? target[attr] : nil
      end
    end

    target_data.map { |data| apply_mapping(template, data) }
  end

  def task(opts = {})
    targets = resolve_reference(opts)
    { value: targets }
  rescue StandardError => e
    raise $ERROR_INFO, "<#{self.class.name}> #{e.class.to_s.gsub(%r{^#{self.class.name}(::)?}, '')}: #{$ERROR_INFO}", $ERROR_INFO.backtrace
  end
end

IncusInventory.run if $PROGRAM_NAME == __FILE__
