class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/audit_events')
    .description("Get recent audit events")
    .permissions([])
    .params(["since", Integer, "Get audit events with timestamps greater than since",
             :optional => true,
             :default => 0])
    .returns([200, "a list of audit event records"]) \
  do
    json_response(AuditEvent.events_since(params[:since]))
  end

  Endpoint.get('/activity-stream/:uuid')
    .description("Get an audit event by id")
    .permissions([])
    .params(["uuid", String, "The UUID of the event to get"])
    .returns([200, "an audit event"]) \
  do
    json_response(AuditEvent.by_id(params[:uuid]))
  end
end
