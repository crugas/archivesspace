
# Audit Table Activity Stream Development Notes

This branch (`audit-table-activity-stream`) contains the implementation of the
requirements specified in the following documents:

- Request for Comment - ASpace Activity Stream + Audit Table - Public (9/17/2025)
- Activity Stream Scope Statement (2/2/2026)

The branch is currently based on ArchivesSpace v4.2.1.

This document summarizes the technical design and motivations for key design
decisions. It also provides some guidance on configuration and testing.


## Database migrations

There are database migrations required for this functionality. The migrations
add four new tables. No existing table definitions or data are changed by the
migrations. The new tables are:
```
audit_event
audit_record
audit_page
audit_page_lock
```


## Configuration

Some configuration is required. The following snippet shows the new lines added
to `common/config/config-defaults.rb`:

```
# Audit logging disabled by default
AppConfig[:enable_audit_logging] = false
# When true, render uris as root-relative in the activity stream API
# Default is to render full uris including scheme, host, etc
AppConfig[:activity_stream_use_relative_uris] = false
# Some object types are opt-in for audit logging
# This array holds their jsonmodel names as strings
# Supported optional types:
#   accession, location, assessment, permission, group, user
AppConfig[:audit_logging_include_object_types] = []
```

A minimal configuration that enables audit logging:
```
AppConfig[:enable_audit_logging] = true
```

## Endpoints

```
/activity-stream
/activity-stream/:object_type
/activity-stream/:object_type/page/:page
/activity-stream/event/:uuid
/activity-stream/object_types
/activity-stream/page/:page
```

## Storage Considerations

## Bulk Events

## Pagination

## Enforcing audit logging in Migrations

## Tests

