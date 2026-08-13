class AuditEvent
  OBJECT_TYPES =
    [
     OBJECT_TYPE_REPOSITORY = 1,
     OBJECT_TYPE_AGENT_PERSON = 2,
     OBJECT_TYPE_AGENT_FAMILY = 3,
     OBJECT_TYPE_AGENT_CORPORATE_ENTITY = 4,
     OBJECT_TYPE_AGENT_SOFTWARE = 5,
     OBJECT_TYPE_RESOURCE = 6,
     OBJECT_TYPE_ARCHIVAL_OBJECT = 7,
     OBJECT_TYPE_DIGITAL_OBJECT = 8,
     OBJECT_TYPE_DIGITAL_OBJECT_COMPONENT = 9,
     OBJECT_TYPE_TOP_CONTAINER = 10,
     OBJECT_TYPE_CONTAINER_PROFILE = 11,
     OBJECT_TYPE_SUBJECT = 12,
     OBJECT_TYPE_CLASSIFICATION = 13,

     OBJECT_TYPE_ACCESSION = 14,
     OBJECT_TYPE_LOCATION = 15,
     OBJECT_TYPE_ASSESSMENT = 16,
     OBJECT_TYPE_PERMISSION = 17,
     OBJECT_TYPE_GROUP = 18,
     OBJECT_TYPE_USER = 19,
    ]

  OBJECT_TYPE_CODE_TABLE =
    {
     OBJECT_TYPE_REPOSITORY => 'repository',
     OBJECT_TYPE_AGENT_PERSON => 'agent_person',
     OBJECT_TYPE_AGENT_FAMILY => 'agent_family',
     OBJECT_TYPE_AGENT_CORPORATE_ENTITY => 'agent_corporate_entity',
     OBJECT_TYPE_AGENT_SOFTWARE => 'agent_software',
     OBJECT_TYPE_RESOURCE => 'resource',
     OBJECT_TYPE_ARCHIVAL_OBJECT => 'archival_object',
     OBJECT_TYPE_DIGITAL_OBJECT => 'digital_object',
     OBJECT_TYPE_DIGITAL_OBJECT_COMPONENT => 'digital_object_component',
     OBJECT_TYPE_TOP_CONTAINER => 'top_container',
     OBJECT_TYPE_CONTAINER_PROFILE => 'container_profile',
     OBJECT_TYPE_SUBJECT => 'subject',
     OBJECT_TYPE_CLASSIFICATION => 'classification',

     OBJECT_TYPE_ACCESSION => 'accession',
     OBJECT_TYPE_LOCATION => 'location',
     OBJECT_TYPE_ASSESSMENT => 'assessment',
     OBJECT_TYPE_PERMISSION => 'permission',
     OBJECT_TYPE_GROUP => 'group',
     OBJECT_TYPE_USER => 'user',
    }

  OPTIONAL_OBJECT_TYPES =
    [
     OBJECT_TYPE_ACCESSION,
     OBJECT_TYPE_LOCATION,
     OBJECT_TYPE_ASSESSMENT,
     OBJECT_TYPE_PERMISSION,
     OBJECT_TYPE_GROUP,
     OBJECT_TYPE_USER,
    ]

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
     CHANGE_METHOD_MANAGE_TOP_CONTAINERS = 7,
     CHANGE_METHOD_MANAGE_ENUMERATIONS = 8,
     CHANGE_METHOD_REORDER = 9,
     CHANGE_METHOD_MIGRATION = 10,
    ]

# FIXME: add these?
#- Duplicate record
# and think about splitting out different importers

  CHANGE_METHOD_CODE_TABLE =
    {
     CHANGE_METHOD_API => 'API',
     CHANGE_METHOD_FORM => 'Staff UI Form',
     CHANGE_METHOD_IMPORTER => 'Importer',
     CHANGE_METHOD_JOB => 'Background Job',
     CHANGE_METHOD_BULK => 'Bulk Spreadsheet',
     CHANGE_METHOD_RAPID => 'Rapid Data Entry',
     CHANGE_METHOD_MANAGE_TOP_CONTAINERS => 'Manage Top Containers',
     CHANGE_METHOD_MANAGE_ENUMERATIONS => 'Manage Enumerations',
     CHANGE_METHOD_REORDER => 'Reorder',
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
