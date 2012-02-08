# encoding: utf-8

require 'coffee'

Mail.defaults do
  delivery_method :test
  retriever_method :test
end

describe Coffee do
  include Mail::Matchers

  before do
    @mails = YAML::load(File.read(
      File.expand_path('../fixtures/mails.yml', __FILE__)))
    Mail::TestRetriever.emails = @mails.map do |mail|
      config = mail.dup
      config.delete :attachments
      retval = Mail.new(config)
      mail[:attachments].each do |attachment|
        retval.add_file attachment
      end
      retval
    end
  end

  context '#chat_log' do
    it 'gets a chat log' do
      subject.chat_log.should == @mails[0][:attachments][0][:content]
    end

    it 'deletes the read mail' do
      2.times do |idx|
        expect do
          subject.chat_log.should == @mails[idx][:attachments][0][:content]
        end.to change { Mail.all.size }.by(-1)
      end
    end
  end

  context '#parse' do
    it 'handles with a person, a day and only text' do
      subject.parse(@mails[2][:attachments][0][:content]).should == {
        'username' => 'kakaotest',
        'sms_logs' => [
          {
            'length' => 12,
            'smstype' => 'incoming',
            'body' => 'text',
            'phonenumber' => '이민우',
            'date' => '2012-02-08 13:11:00',
            'contact_id' => -1,
            'thread_id' => -1,
          },
          {
            'length' => 12,
            'smstype' => 'incoming',
            'body' => 'text',
            'phonenumber' => '이민우',
            'date' => '2012-02-08 13:11:00',
            'contact_id' => -1,
            'thread_id' => -1,
          },
          {
            'length' => 12,
            'smstype' => 'outgoing',
            'body' => 'text',
            'phonenumber' => '이민우',
            'date' => '2012-02-08 13:11:00',
            'contact_id' => -1,
            'thread_id' => -1,
          },
        ]
      }
    end

    it 'handles with a person, two days and text/image' do
      subject.parse(@mails[0][:attachments][0][:content]).should == {
        "username"=>"kakaotest",
        "sms_logs"=>[
          {
            "length"=>5,
            "smstype"=>"outgoing",
            "body"=>"text",
            "phonenumber"=>"이민우",
            "date"=>"2012-01-31 19:11:00",
            "contact_id"=>-1,
            "thread_id"=>-1
          },
          {
            "length"=>8,
            "smstype"=>"outgoing",
            "body"=>"image",
            "phonenumber"=>"이민우",
            "date"=>"2012-02-01 12:56:00",
            "contact_id"=>-1,
            "thread_id"=>-1
          }
        ]
      }
    end

    it 'handles with two people, a day and only text' do
      subject.parse(@mails[3][:attachments][0][:content]).should == {
        "username"=>"kakaotest",
        "sms_logs"=>[
          {
            "length"=>3,
            "smstype"=>"outgoing",
            "body"=>"text",
            "phonenumber"=>"이민우, 강다혜",
            "date"=>"2012-02-08 15:13:00",
            "contact_id"=>-1,
            "thread_id"=>-1
          },
          {
            "length"=>3,
            "smstype"=>"incoming",
            "body"=>"text",
            "phonenumber"=>"이민우, 강다혜",
            "date"=>"2012-02-08 15:13:00",
            "contact_id"=>-1,
            "thread_id"=>-1
          },
          {
            "length"=>3,
            "smstype"=>"incoming",
            "body"=>"text",
            "phonenumber"=>"강다혜, 이민우",
            "date"=>"2012-02-08 15:17:00",
            "contact_id"=>-1,
            "thread_id"=>-1
          }
        ]
      }
    end
  end
end
