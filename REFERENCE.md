# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Tasks

* [`resolve_reference`](#resolve_reference): Generate targets from Incus or LXD

## Tasks

### <a name="resolve_reference"></a>`resolve_reference`

Generate targets from Incus or LXD

**Supports noop?** false

#### Parameters

##### `provider`

Data type: `Optional[Enum['incus', 'lxd']]`

which service to use, prefers incus if unset

##### `remote`

Data type: `Optional[String]`

name of remote in configuration

##### `filter`

Data type: `Optional[String]`

instances collection filter passed directly to api call

##### `project`

Data type: `Optional[String]`

limit instances to specific project

##### `all_projects`

Data type: `Boolean`

query all projects

##### `target_mapping`

Data type: `Hash`

target attributes to populate with resource values

