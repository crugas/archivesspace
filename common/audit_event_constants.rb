class AuditEvent

# FIXME: think about enumerations
# looks like this is the endpoint we care about:
# /config/enumerations/migration
# and it's not the enumeration itself, but the records that use it that we care about

# FIXME: these object types are not included by default
# but can be added in config:
# Accession
# Locations
# Assessments
# Permissions
# Groups
# User

  OBJECT_TYPES =
    [
     OBJECT_TYPE_REPOSITORY = 1,
     OBJECT_TYPE_AGENT_PERSON = 2,
     OBJECT_TYPE_AGENT_FAMILY = 3,
     OBJECT_TYPE_AGENT_CORPORATE_ENTITY = 4,
     OBJECT_TYPE_AGENT_SOFTWARE = 5,
     OBJECT_TYPE_ACCESSION = 6,
     OBJECT_TYPE_RESOURCE = 7,
     OBJECT_TYPE_ARCHIVAL_OBJECT = 8,
     OBJECT_TYPE_DIGITAL_OBJECT = 9,
     OBJECT_TYPE_DIGITAL_OBJECT_COMPONENT = 10,
     OBJECT_TYPE_TOP_CONTAINER = 11,
     OBJECT_TYPE_CONTAINER_PROFILE = 12,
     OBJECT_TYPE_SUBJECT = 13,
     OBJECT_TYPE_CLASSIFICATION = 14,
    ]

  OBJECT_TYPE_CODE_TABLE =
    {
     OBJECT_TYPE_REPOSITORY => 'repository',
     OBJECT_TYPE_AGENT_PERSON => 'agent_person',
     OBJECT_TYPE_AGENT_FAMILY => 'agent_family',
     OBJECT_TYPE_AGENT_CORPORATE_ENTITY => 'agent_corporate_entity',
     OBJECT_TYPE_AGENT_SOFTWARE => 'agent_software',
     OBJECT_TYPE_ACCESSION => 'accession',
     OBJECT_TYPE_RESOURCE => 'resource',
     OBJECT_TYPE_ARCHIVAL_OBJECT => 'archival_object',
     OBJECT_TYPE_DIGITAL_OBJECT => 'digital_object',
     OBJECT_TYPE_DIGITAL_OBJECT_COMPONENT => 'digital_object_component',
     OBJECT_TYPE_TOP_CONTAINER => 'top_container',
     OBJECT_TYPE_CONTAINER_PROFILE => 'container_profile',
     OBJECT_TYPE_SUBJECT => 'subject',
     OBJECT_TYPE_CLASSIFICATION => 'classification',
    }

  # a subset of the types in the standard
  # FIXME: no special handling for publish - just an update
  ACTIVITY_TYPES =
    [
     ACTIVITY_TYPE_ADD = 1,
     ACTIVITY_TYPE_CREATE = 2,
     ACTIVITY_TYPE_DELETE = 3,
     ACTIVITY_TYPE_MOVE = 4,
     ACTIVITY_TYPE_REMOVE = 5,
     ACTIVITY_TYPE_UPDATE = 6
    ]

  ACTIVITY_TYPE_CODE_TABLE =
    {
     ACTIVITY_TYPE_ADD => 'Add',
     ACTIVITY_TYPE_CREATE => 'Create',
     ACTIVITY_TYPE_DELETE => 'Delete',
     ACTIVITY_TYPE_MOVE => 'Move',
     ACTIVITY_TYPE_REMOVE => 'Remove',
     ACTIVITY_TYPE_UPDATE => 'Update',
    }

  CHANGE_METHODS =
    [
     CHANGE_METHOD_API = 1,
     CHANGE_METHOD_FORM = 2,
     CHANGE_METHOD_IMPORTER = 3,
     CHANGE_METHOD_JOB = 4,
     CHANGE_METHOD_BULK = 5,
     CHANGE_METHOD_RAPID = 6,
     CHANGE_METHOD_MIGRATION = 7,
    ]

  CHANGE_METHOD_LOOKUP =
    {
     'API' => CHANGE_METHOD_API,
     'FORM' => CHANGE_METHOD_FORM,
     'IMPORTER' => CHANGE_METHOD_IMPORTER,
     'JOB' => CHANGE_METHOD_JOB,
     'BULK' => CHANGE_METHOD_BULK,
     'RAPID' => CHANGE_METHOD_RAPID,
     'MIGRATION' => CHANGE_METHOD_MIGRATION,
    }

# add these
#- Duplicate record
#- Manage top containers
#- Reorder mode

  CHANGE_METHOD_CODE_TABLE =
    {
     CHANGE_METHOD_API => 'API',
     CHANGE_METHOD_FORM => 'Staff UI Form',
     CHANGE_METHOD_IMPORTER => 'Importer',
     CHANGE_METHOD_JOB => 'Background Job',
     CHANGE_METHOD_BULK => 'Bulk Spreadsheet',
     CHANGE_METHOD_RAPID => 'Rapid Data Entry',
     CHANGE_METHOD_MIGRATION => 'Database Migration',
    }

  ROLES =
    [
     ROLE_OBJECT = 1,
     ROLE_SOURCE = 2,
     ROLE_TARGET = 3
    ]

  ROLE_CODE_TABLE =
    {
     ROLE_OBJECT => 'object',
     ROLE_SOURCE => 'source',
     ROLE_TARGET => 'target'
    }

  ACTOR_TYPES =
    [
     ACTOR_TYPE_APPLICATION = 1,
     ACTOR_TYPE_PERSON = 2,
     ACTOR_TYPE_SERVICE = 3
    ]

  ACTOR_TYPE_CODE_TABLE =
    {
     ACTOR_TYPE_APPLICATION => 'Application',
     ACTOR_TYPE_PERSON => 'Person',
     ACTOR_TYPE_SERVICE => 'Service'
    }
end
