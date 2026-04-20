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
end
