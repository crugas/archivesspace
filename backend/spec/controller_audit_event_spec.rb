require 'spec_helper'

describe 'AuditEvent controller' do

  def create_audit_event(uuid:, timestamp:, activity_type:, records:, actor_name: 'admin',
                         actor_type: AuditEvent::ACTOR_TYPE_PERSON,
                         change_method: AuditEvent::CHANGE_METHOD_API)
    event_id = $testdb[:audit_event].insert(:uuid => uuid,
                                            :timestamp => timestamp,
                                            :actor_name => actor_name,
                                            :actor_type => actor_type,
                                            :activity_type => activity_type,
                                            :change_method => change_method)

    records.each do |record|
      $testdb[:audit_record].insert(:audit_event_id => event_id,
                                    :uri => record[:uri],
                                    :type => record[:type],
                                    :role => record[:role])
    end

    {:id => event_id, :uuid => uuid, :timestamp => timestamp}
  end

  before(:each) do
    @resource = create(:json_resource)
    @accession = create(:json_accession)
  end

  it 'returns audit events newer than the supplied timestamp' do
    older = create_audit_event(:uuid => 'older-event',
                               :timestamp => Time.utc(2024, 1, 1, 10, 0, 0),
                               :activity_type => AuditEvent::ACTIVITY_TYPE_CREATE,
                               :records => [{:role => AuditEvent::ROLE_OBJECT,
                                             :type => 'resource',
                                             :uri => @resource.uri}])

    newer = create_audit_event(:uuid => 'newer-event',
                               :timestamp => Time.utc(2024, 1, 1, 10, 5, 0),
                               :activity_type => AuditEvent::ACTIVITY_TYPE_UPDATE,
                               :records => [{:role => AuditEvent::ROLE_OBJECT,
                                             :type => 'accession',
                                             :uri => @accession.uri}])

    response = as_test_user('admin') do
      get '/audit_events', :since => older[:timestamp].to_i + 1
      expect(last_response).to be_ok
      ASUtils.json_parse(last_response.body)
    end

    expect(response.length).to eq(1)
    expect(response[0]['id']).to eq(AuditEvent.activity_stream_uri("/event/#{newer[:uuid]}"))
    expect(response[0]['type']).to eq('Update')
    expect(response[0]['object']['id']).to eq(AuditEvent.archivesspace_uri(@accession.uri))
  end

  it 'returns activity stream metadata for a specific object type' do
    create_audit_event(:uuid => 'resource-event',
                       :timestamp => Time.utc(2024, 1, 1, 10, 0, 0),
                       :activity_type => AuditEvent::ACTIVITY_TYPE_CREATE,
                       :records => [{:role => AuditEvent::ROLE_OBJECT,
                                     :type => 'resource',
                                     :uri => @resource.uri}])

    create_audit_event(:uuid => 'accession-event',
                       :timestamp => Time.utc(2024, 1, 1, 10, 5, 0),
                       :activity_type => AuditEvent::ACTIVITY_TYPE_CREATE,
                       :records => [{:role => AuditEvent::ROLE_OBJECT,
                                     :type => 'accession',
                                     :uri => @accession.uri}])

    response = as_test_user('admin') do
      get '/activity-stream/resource'
      expect(last_response).to be_ok
      ASUtils.json_parse(last_response.body)
    end

    expect(response['type']).to eq('OrderedCollection')
    expect(response['totalItems']).to eq(1)
    expect(response['first']).to eq(AuditEvent.activity_stream_uri('/resource/page/1'))
    expect(response['last']).to eq(AuditEvent.activity_stream_uri('/resource/page/1'))
  end

  it 'returns activity stream pages and single events by uuid' do
    event = create_audit_event(:uuid => 'page-event',
                               :timestamp => Time.utc(2024, 1, 1, 10, 0, 0),
                               :activity_type => AuditEvent::ACTIVITY_TYPE_CREATE,
                               :records => [{:role => AuditEvent::ROLE_OBJECT,
                                             :type => 'resource',
                                             :uri => @resource.uri}])

    page = as_test_user('admin') do
      get '/activity-stream/page/1'
      expect(last_response).to be_ok
      ASUtils.json_parse(last_response.body)
    end

    expect(page['type']).to eq('OrderedCollectionPage')
    expect(page['orderedItems'].length).to eq(1)
    expect(page['orderedItems'][0]['id']).to eq(AuditEvent.activity_stream_uri("/event/#{event[:uuid]}"))

    fetched = as_test_user('admin') do
      get "/activity-stream/event/#{event[:uuid]}"
      expect(last_response).to be_ok
      ASUtils.json_parse(last_response.body)
    end

    expect(fetched['id']).to eq(AuditEvent.activity_stream_uri("/event/#{event[:uuid]}"))
    expect(fetched['object']['id']).to eq(AuditEvent.archivesspace_uri(@resource.uri))
  end
end
