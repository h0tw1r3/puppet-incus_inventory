# [Incus] and [LXD] inventory for [Bolt]

## Table of Contents

1. [Description](#description)
1. [Requirements](#requirements)
1. [Usage](#usage)
1. [Examples](#examples)

## Description

A [Bolt plugin] for dynamically generating targets for instances managed by
[Incus] or [LXD].

## Requirements

* A working client configuration with at least one [remote].
  _Does not_ require the client, [REST API] calls are made directly.

If the command `incus list` or `lxd list` works, _this plugin should too._

## Usage

Inventory task parameters:

| parameter      | type             | description                                                | default          |
|----------------|------------------|------------------------------------------------------------|------------------|
| all_projects   | Boolean          | query all projects                                         | `false`          |
| filter         | Optional[String] | instances collection filter passed directly to api call    |                  |
| project        | Optional[String] | limit instances to specific project                        |                  |
| provider       | Optional[Enum['incus', 'lxd']] | which service to use, _prefers incus if unset_ |                |
| remote         | Optional[String] | name of [remote] in configuration                          |                  |
| target_mapping | Hash             | hash of target attributes to populate with resource values | `{ name: name }` |

## Examples

```
groups:
  - name: containers on dc1 remote
    targets:
      - _plugin: incus_inventory
        remote: dc1
        filter: type eq container
  - name: vms on default remote
    targets:
      - _plugin: incus_inventory
        filter: type eq virtual-machine
        target_mapping:
          name: name
          alias: state.network.nic0.addresses.0.address
          vars:
            arch: architecture
  - name: all debian instances
    targets:
      - _plugin: incus_inventory
        filter: config.image.os eq Debian
```

[Bolt plugin]: https://www.puppet.com/docs/bolt/latest/writing_plugins.html
[remote]: https://linuxcontainers.org/incus/docs/main/remotes/
[REST API]: https://linuxcontainers.org/incus/docs/main/api/
[Bolt]: https://puppet.com/docs/bolt/latest/bolt.html
[Incus]: https://linuxcontainers.org/incus/
[LXD]: https://canonical.com/lxd
