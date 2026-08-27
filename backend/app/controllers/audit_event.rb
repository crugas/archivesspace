class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/activity-stream/object_types')
    .description("Get a list of supported object types")
    .permissions([])
    .params()
    .returns([200, "a list of supported object types"]) \
  do
    json_response(AuditEvent.all_activity_streams)
  end

  Endpoint.get('/activity-stream')
    .description("Get an OrderedCollection of events for all object types")
    .permissions([])
    .params()
    .returns([200, "an OrderedCollection"]) \
  do
    activity_json_response(AuditEvent.activity_stream)
  end

  Endpoint.get('/activity-stream/page/:page')
    .description("Get a page of the activity stream")
    .permissions([])
    .params(["page", Integer, "The page to get"])
    .returns([200, "an OrderedCollectionPage"]) \
  do
    result = AuditEvent.page(params[:page])

    if result
      activity_json_response(result)
    else
      raise NotFoundException.new("page not available")
    end
  end

  Endpoint.get('/activity-stream/event/:uuid')
    .description("Get an audit event by id")
    .permissions([])
    .params(["uuid", String, "The UUID of the event to get"])
    .returns([200, "an audit event"]) \
  do
    result = AuditEvent.by_id(params[:uuid])

    if result
      activity_json_response(result)
    else
      raise NotFoundException.new("event not available")
    end
  end

  Endpoint.get('/activity-stream/:object_type')
    .description("Get an OrderedCollection of events for object type")
    .permissions([])
    .params(["object_type", String, "The type of object to events for"])
    .returns([200, "an OrderedCollection"]) \
  do
    activity_json_response(AuditEvent.activity_stream(params[:object_type]))
  end

  Endpoint.get('/activity-stream/:object_type/page/:page')
    .description("Get a page of the activity stream for object type")
    .permissions([])
    .params(["object_type", String, "The type of object to events for"],
            ["page", Integer, "The page to get"])
    .returns([200, "an OrderedCollectionPage"]) \
  do
    result = AuditEvent.page(params[:page], params[:object_type])

    if result
      activity_json_response(result)
    else
      raise NotFoundException.new("page not available")
    end
  end

  def activity_json_response(obj, status = 200)
    [status, {"Content-Type" => "application/activity+json"}, [obj.to_json(:mode => :trusted, :max_nesting => false) + "\n"]]
  end
end
