require 'spec_helper'
require_relative '../../common/db/migrations/utils'

describe 'AuditEvent model' do

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

  def capture_log_event_calls
    calls = []

    allow(AuditEvent).to receive(:log_event) do |activity_type, records, opts = {}|
      calls << {
        :activity_type => activity_type,
        :records => records,
        :opts => opts,
        :change_method => RequestContext.get(:change_method)
      }
    end

    calls
  end

  def enable_audit_logging
    allow(AppConfig).to receive(:[]).and_call_original
    allow(AppConfig).to receive(:[]).with(:enable_audit_logging).and_return(true)
    allow(AppConfig).to receive(:[]).with(:audit_logging_include_object_types).and_return(['accession', 'resource'])
  end

  before(:each) do
    @resource = create(:json_resource)
    @accession = create(:json_accession)
  end

  it 'marks merge events when the target is included in the moved objects' do
    rendered = AuditEvent.render(:uuid => 'merge-event',
                                 :timestamp => Time.utc(2024, 1, 1, 10, 0, 0),
                                 :actor_name => 'admin',
                                 :actor_type => AuditEvent::ACTOR_TYPE_PERSON,
                                 :activity_type => AuditEvent::ACTIVITY_TYPE_MOVE,
                                 :change_method => AuditEvent::CHANGE_METHOD_API,
                                 :records => "#{AuditEvent::ROLE_OBJECT}:resource:#{@resource.uri}," \
                                             "#{AuditEvent::ROLE_TARGET}:resource:#{@resource.uri}")

    expect(rendered[:type]).to eq('Move')
    expect(rendered[:summary]).to eq('merge')
    expect(rendered['target'][:id]).to eq(AuditEvent.archivesspace_uri(@resource.uri))
  end

  it 'returns an empty ordered collection when there are no audit events' do
    $testdb[:audit_record].delete
    $testdb[:audit_event].delete

    response = AuditEvent.activity_stream

    expect(response[:type]).to eq('OrderedCollection')
    expect(response[:totalItems]).to eq(0)
    expect(response).not_to have_key(:first)
    expect(response).not_to have_key(:last)
  end

  it 'builds filtered activity stream pages with the expected navigation links' do
    stub_const('AuditEvent::PAGE_SIZE', 2)

    create_audit_event(:uuid => 'resource-event-1',
                       :timestamp => Time.utc(2024, 1, 1, 10, 0, 0),
                       :activity_type => AuditEvent::ACTIVITY_TYPE_CREATE,
                       :records => [{:role => AuditEvent::ROLE_OBJECT,
                                     :type => 'resource',
                                     :uri => @resource.uri}])

    second_resource = create(:json_resource)
    third_resource = create(:json_resource)

    create_audit_event(:uuid => 'resource-event-2',
                       :timestamp => Time.utc(2024, 1, 1, 10, 5, 0),
                       :activity_type => AuditEvent::ACTIVITY_TYPE_UPDATE,
                       :records => [{:role => AuditEvent::ROLE_OBJECT,
                                     :type => 'resource',
                                     :uri => second_resource.uri}])

    create_audit_event(:uuid => 'resource-event-3',
                       :timestamp => Time.utc(2024, 1, 1, 10, 10, 0),
                       :activity_type => AuditEvent::ACTIVITY_TYPE_UPDATE,
                       :records => [{:role => AuditEvent::ROLE_OBJECT,
                                     :type => 'resource',
                                     :uri => third_resource.uri}])

    create_audit_event(:uuid => 'accession-event-1',
                       :timestamp => Time.utc(2024, 1, 1, 10, 15, 0),
                       :activity_type => AuditEvent::ACTIVITY_TYPE_CREATE,
                       :records => [{:role => AuditEvent::ROLE_OBJECT,
                                     :type => 'accession',
                                     :uri => @accession.uri}])

    response = AuditEvent.page(2, 'resource')

    expect(response[:type]).to eq('OrderedCollectionPage')
    expect(response[:prev][:id]).to eq(AuditEvent.activity_stream_uri('/resource/page/1'))
    expect(response).not_to have_key(:next)
    expect(response[:orderedItems].length).to eq(1)
    expect(response[:orderedItems][0][:id]).to eq(AuditEvent.activity_stream_uri('/event/resource-event-3'))
    expect(response[:orderedItems][0]['object'][:id]).to eq(AuditEvent.archivesspace_uri(third_resource.uri))
  end

  it 'logs audit events using the request context actor and change method' do
    enable_audit_logging

    RequestContext.put(:current_username, 'audit_user')
    RequestContext.put(:change_method, AuditEvent::CHANGE_METHOD_FORM)

    expect {
      AuditEvent.log_event(AuditEvent::ACTIVITY_TYPE_CREATE,
                           {AuditEvent::ROLE_OBJECT => @resource.uri})
    }.to change {$testdb[:audit_event].count}.by(1)

    event = $testdb[:audit_event].order(Sequel.desc(:id)).first
    records = $testdb[:audit_record].where(:audit_event_id => event[:id]).all

    expect(event[:actor_name]).to eq('audit_user')
    expect(event[:change_method]).to eq(AuditEvent::CHANGE_METHOD_FORM)
    expect(records.length).to eq(1)
    expect(records[0][:role]).to eq(AuditEvent::ROLE_OBJECT)
    expect(records[0][:type]).to eq('resource')
    expect(records[0][:uri]).to eq(@resource.uri)
  end

  describe 'log_event guard branches' do
    it 'does not log when audit logging is disabled' do
      allow(AppConfig).to receive(:[]).and_call_original
      allow(AppConfig).to receive(:[]).with(:enable_audit_logging).and_return(false)

      expect {
        AuditEvent.log_event(AuditEvent::ACTIVITY_TYPE_CREATE,
                             {AuditEvent::ROLE_OBJECT => @resource.uri},
                             :actor => 'audit_user')
      }.not_to change {$testdb[:audit_event].count}
    end

    it 'does not log when there are no affected records' do
      enable_audit_logging

      expect {
        AuditEvent.log_event(AuditEvent::ACTIVITY_TYPE_CREATE,
                             {AuditEvent::ROLE_OBJECT => []},
                             :actor => 'audit_user')
      }.not_to change {$testdb[:audit_event].count}
    end

    it 'warns and returns for unsupported activity types' do
      enable_audit_logging
      allow(Log).to receive(:warn)

      expect {
        AuditEvent.log_event(999,
                             {AuditEvent::ROLE_OBJECT => @resource.uri},
                             :actor => 'audit_user')
      }.not_to change {$testdb[:audit_event].count}

      expect(Log).to have_received(:warn).with('Failed to log Audit Event - unsupported Activity Type: 999')
    end

    it 'warns and returns when no actor is available' do
      enable_audit_logging
      RequestContext.put(:current_username, nil)
      allow(Log).to receive(:warn)

      expect {
        AuditEvent.log_event(AuditEvent::ACTIVITY_TYPE_CREATE,
                             {AuditEvent::ROLE_OBJECT => @resource.uri})
      }.not_to change {$testdb[:audit_event].count}

      expect(Log).to have_received(:warn).with('Failed to log Audit Event - no Actor provided and no current username')
    end

    it 'skips invalid records while still logging supported ones' do
      enable_audit_logging
      allow(Log).to receive(:warn)
      allow(Log).to receive(:debug)

      expect {
        AuditEvent.log_event(AuditEvent::ACTIVITY_TYPE_UPDATE,
                             {AuditEvent::ROLE_OBJECT => ['not-a-uri', '/users/1', @resource.uri]},
                             :actor => 'audit_user')
      }.to change {$testdb[:audit_event].count}.by(1)

      event = $testdb[:audit_event].order(Sequel.desc(:id)).first
      records = $testdb[:audit_record].where(:audit_event_id => event[:id]).all

      expect(records.length).to eq(1)
      expect(records[0][:role]).to eq(AuditEvent::ROLE_OBJECT)
      expect(records[0][:type]).to eq('resource')
      expect(records[0][:uri]).to eq(@resource.uri)
      expect(Log).to have_received(:warn).with('Failed to log Audit Event Record - failed to parse URI: not-a-uri')
      expect(Log).to have_received(:debug).with('Skipping Audit Record - unsupported Object Type: user')
    end

    it 'does not log when every parsed record is discarded' do
      enable_audit_logging
      allow(Log).to receive(:warn)
      allow(Log).to receive(:debug)

      expect {
        AuditEvent.log_event(AuditEvent::ACTIVITY_TYPE_UPDATE,
                             {AuditEvent::ROLE_OBJECT => ['not-a-uri', '/users/1']},
                             :actor => 'audit_user')
      }.not_to change {$testdb[:audit_event].count}

      expect(Log).to have_received(:warn).with('Failed to log Audit Event Record - failed to parse URI: not-a-uri')
      expect(Log).to have_received(:debug).with('Skipping Audit Record - unsupported Object Type: user')
    end
  end

  describe 'change method entry paths' do
    it 'defaults to API when no explicit change method is present' do
      enable_audit_logging
      RequestContext.put(:change_method, nil)

      before_count = $testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_API).count

      AuditEvent.log_event(AuditEvent::ACTIVITY_TYPE_CREATE,
                           {AuditEvent::ROLE_OBJECT => @resource.uri})

      after_count = $testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_API).count

      expect(after_count).to eq(before_count + 1)
    end

    it 'records FORM via the Rack request header path' do
      enable_audit_logging

      before_count = $testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_FORM).count

      post "/repositories/#{$repo_id}/accessions",
           build(:json_accession).to_json,
           {
             'CONTENT_TYPE' => 'application/json',
             'HTTP_X_ARCHIVESSPACE_CHANGE_METHOD' => AuditEvent::CHANGE_METHOD_FORM.to_s
           }

      expect(last_response).to be_ok
      after_count = $testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_FORM).count

      expect(after_count).to eq(before_count + 1)
    end

    it 'records RAPID via the component add children endpoint' do
      enable_audit_logging
      resource = create(:json_resource)

      archival_object = build(:json_archival_object, :dates => [])
      children = JSONModel(:archival_record_children).from_hash({
        'children' => [archival_object]
      })

      before_count = $testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_RAPID).count

      url = URI("#{JSONModel::HTTP.backend_url}#{resource.uri}/children")
      response = JSONModel::HTTP.post_json(url, children.to_json)

      expect(response.code).to eq('200')
      expect($testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_RAPID).count).to eq(before_count + 1)
    end

    it 'records MIGRATION via the migration audit logger' do
      before_count = $testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_MIGRATION).count

      AuditEventLogger.new($testdb).log_update_event(AuditEvent::OBJECT_TYPE_RESOURCE, @resource.uri)

      event = $testdb[:audit_event].order(Sequel.desc(:id)).first

      expect($testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_MIGRATION).count).to eq(before_count + 1)
      expect(event[:change_method]).to eq(AuditEvent::CHANGE_METHOD_MIGRATION)
    end
  end

  describe 'ASModel_crud log_event' do
    it 'logs create events from create_from_json' do
      audit_calls = capture_log_event_calls

      accession = Accession.create_from_json(build(:json_accession), :repo_id => $repo_id)

      call = audit_calls.find do |audit_call|
        audit_call[:activity_type] == AuditEvent::ACTIVITY_TYPE_CREATE &&
          audit_call[:records] == {
            AuditEvent::ROLE_OBJECT => JSONModel(:accession).uri_for(accession.id, :repo_id => $repo_id)
          }
      end

      expect(call).not_to be_nil
    end

    it 'logs update events from update_from_json' do
      accession = create(:json_accession)
      audit_calls = capture_log_event_calls

      json = Accession.to_jsonmodel(accession.id)
      json.title = 'Updated accession title'

      Accession[accession.id].update_from_json(json)

      call = audit_calls.find do |audit_call|
        audit_call[:activity_type] == AuditEvent::ACTIVITY_TYPE_UPDATE &&
          audit_call[:records] == {AuditEvent::ROLE_OBJECT => accession.uri}
      end

      expect(call).not_to be_nil
    end

    it 'logs delete events from delete' do
      accession = create(:json_accession)
      audit_calls = capture_log_event_calls

      Accession[accession.id].delete

      expect(audit_calls.length).to eq(1)
      expect(audit_calls[0][:activity_type]).to eq(AuditEvent::ACTIVITY_TYPE_DELETE)
      expect(audit_calls[0][:records]).to eq(AuditEvent::ROLE_OBJECT => accession.uri)
    end
  end

  describe 'TreeNodes log_event' do
    it 'logs reorder updates from set_position_in_list' do
      resource = create(:json_resource)
      ao_1 = create(:json_archival_object, :dates => [], :resource => {:ref => resource.uri}, :title => 'AO1')
      create(:json_archival_object, :dates => [], :resource => {:ref => resource.uri}, :title => 'AO2')
      ao_3 = create(:json_archival_object, :dates => [], :resource => {:ref => resource.uri}, :title => 'AO3')

      audit_calls = capture_log_event_calls

      ArchivalObject[ao_1.id].set_position_in_list(1)

      expect(audit_calls.length).to eq(1)
      expect(audit_calls[0][:activity_type]).to eq(AuditEvent::ACTIVITY_TYPE_UPDATE)
      expect(audit_calls[0][:change_method]).to eq(AuditEvent::CHANGE_METHOD_REORDER)
      expect(audit_calls[0][:records].keys).to eq([AuditEvent::ROLE_OBJECT])
      expect(audit_calls[0][:records][AuditEvent::ROLE_OBJECT]).to contain_exactly(ao_1.uri, ao_3.uri)
    end
  end

  describe 'Relationships log_event' do
    it 'logs move events from assimilate' do
      merge_destination = create(:json_subject)
      merge_candidate = create(:json_subject)
      audit_calls = capture_log_event_calls

      Subject[merge_destination.id].assimilate([Subject[merge_candidate.id]])

      call = audit_calls.find do |audit_call|
        audit_call[:activity_type] == AuditEvent::ACTIVITY_TYPE_MOVE
      end

      expect(call).not_to be_nil
      expect(call[:records][AuditEvent::ROLE_OBJECT]).to contain_exactly(merge_destination.uri, merge_candidate.uri)
      expect(call[:records][AuditEvent::ROLE_TARGET]).to eq(merge_destination.uri)
    end
  end

  describe 'TopContainer log_event' do
    it 'logs batch updates through log_audit_event_for_batch' do
      top_container = create(:json_top_container)
      audit_calls = capture_log_event_calls

      TopContainer.log_audit_event_for_batch([top_container.id])

      expect(audit_calls.length).to eq(1)
      expect(audit_calls[0][:activity_type]).to eq(AuditEvent::ACTIVITY_TYPE_UPDATE)
      expect(audit_calls[0][:change_method]).to eq(AuditEvent::CHANGE_METHOD_MANAGE_TOP_CONTAINERS)
      expect(audit_calls[0][:records]).to eq(AuditEvent::ROLE_OBJECT => [top_container.uri])
    end
  end
end
