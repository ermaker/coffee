# encoding: utf-8

require 'coffee'

Mail.defaults do
  delivery_method :test
  retriever_method :test
end

def setup_mails filename
  @mails = YAML::load(File.read(
    File.expand_path("../fixtures/#{filename}", __FILE__)))
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

describe Coffee do
  include Mail::Matchers

  TIMESTAMP_PATH = File.expand_path('../../tmp/timestamp.yml', __FILE__)
  subject { Coffee.new(TIMESTAMP_PATH) }
  after { FileUtils.rm_f(TIMESTAMP_PATH) }

  context 'with mails.yml' do
    before do
      setup_mails('mails.yml')
    end

    context '#chat' do
      it 'gets a chat' do
        subject.chat.should == [@mails[0][:from], @mails[0][:attachments][0][:content]]
      end

      it 'deletes the read mail' do
        2.times do |idx|
          expect do
            subject.chat.should == [@mails[idx][:from], @mails[idx][:attachments][0][:content]]
          end.to change { Mail.all.size }.by(-1)
        end
      end

      it 'returns nil with no mails' do
        Mail.all.size.times { subject.chat }
        subject.chat.should be_nil
      end
    end

    context '#parse' do
      it 'handles with a person, a day and only text' do
        subject.parse(
          'user@email.com', @mails[2][:attachments][0][:content]).should == {
          'username' => 'user@email.com',
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
        subject.parse(
          'user@email.com', @mails[0][:attachments][0][:content]).should == {
          "username"=>"user@email.com",
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
              "date"=>"2012-02-01 00:56:00",
              "contact_id"=>-1,
              "thread_id"=>-1
            }
          ]
        }
      end

      it 'handles with two people, a day and only text' do
        subject.parse(
          'user@email.com', @mails[3][:attachments][0][:content]).should == {
          "username"=>"user@email.com",
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

      it 'handles the username' do
        subject.parse(
          'user2@email.com', @mails[4][:attachments][0][:content]).should == {
          "username"=>"user2@email.com",
          "sms_logs"=>[
            {
              'length' => 12,
              'smstype' => 'incoming',
              'body' => 'text',
              'phonenumber' => '이민우',
              'date' => '2012-02-08 13:11:00',
              'contact_id' => -1,
              'thread_id' => -1,
            }
          ]
        }
      end
    end
  end

  it 'sets and gets time' do
    username = 'user@email.com'
    receivers = ['이민우', '강다혜']
    other_receivers = ['이민우']
    subject[username, receivers].should be_nil
    subject[username, receivers] = Time.at(0)
    subject[username, receivers].should == Time.at(0)
    subject[username, other_receivers].should be_nil
  end

  it '#parse handles the case with duplicate, an user and a person' do
    setup_mails('mails_for_an_user_a_person.yml')
    [3, 2, 5, 6].each do |num|
      subject.parse(*subject.chat)['sms_logs'].should have(num).items
    end
  end

  it '#consume works' do
    Mail::TestMailer.deliveries.clear
    setup_mails('mails_for_an_user_a_person.yml')
    subject.consume
    Mail.all.should be_empty
    Mail::TestMailer.deliveries.each_with_index do |mail,idx|
      mail.from.should == [@mails[idx][:to]]
      mail.to.should == [@mails[idx][:from]]
    end
  end

  context '#parse' do
    ['case1.txt', 'case2.txt'].each do |fn|
      it "works with #{fn}" do
        log = File.read( File.expand_path("../fixtures/#{fn}", __FILE__))
        subject.parse('user@email.com', log)
      end
    end
  end
end
