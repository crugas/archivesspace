require 'spec_helper'
require 'stringio'



describe 'Import job model' do


  before(:all) do
    converter = Class.new(Converter) do
      def self.instance_for(type, input_file)
        self.new(input_file) if type == 'nonce'
      end

      def run
        obj = ASpaceImport::JSONModel(:accession).new
        obj.title = IO.read(@input_file)
        obj.id_0 = '1234'
        obj.accession_date = '2010-10-10'
        @batch << obj
        @batch.flush
      end
    end

    Converter.register_converter(converter)
  end



  let(:job) do
    tmp = ASUtils.tempfile("doc-#{Time.now.to_i}")
    tmp.write("foobar")
    tmp.rewind

    $icky_hack_to_avoid_gc ||= []
    $icky_hack_to_avoid_gc << tmp

    json = build(:json_job,
                 :job_type => 'import_job',
                 :job => build(:json_import_job,
                               :filenames => [tmp.path],
                               :import_type => 'nonce'))


    user = create_nobody_user
    job = Job.create_from_json(json,
                               :repo_id => $repo_id,
                               :user => user)

    job.add_file(tmp)

    job
  end

  it "can create an import job" do
    expect(job).not_to be_nil
  end


  it "can be run and record the results" do
    job_runner = JobRunner.for(job)
    job_runner.run

    expect(job.created_records.count).to eq(1)
    expect(job.created_records.first[:record_uri]).to match(/accessions\/\d+$/)
    expect(Accession[JSONModel(:accession).id_for(job.created_records.first[:record_uri])].title).to eq('foobar')
  end

  it "records audit events with importer change method" do
    allow(AppConfig).to receive(:[]).and_call_original
    allow(AppConfig).to receive(:[]).with(:enable_audit_logging).and_return(true)
    allow(AppConfig).to receive(:[]).with(:audit_logging_include_object_types).and_return(['accession'])


    before_count = $testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_IMPORTER).count

    # mimic the background job runner, which sets the change method to IMPORTER
    RequestContext.open(:change_method => AuditEvent::CHANGE_METHOD_IMPORTER) do
      JobRunner.for(job).run
    end

    expect(job.created_records.count).to eq(1)
    expect($testdb[:audit_event].where(:change_method => AuditEvent::CHANGE_METHOD_IMPORTER).count).to eq(before_count + 1)
  end

end
