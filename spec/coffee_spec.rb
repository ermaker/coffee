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
  USERNAME_PATH = File.expand_path('../fixtures/username.yml', __FILE__)
  before { CSV.stub!(:open) }
  subject { Coffee.new(TIMESTAMP_PATH, USERNAME_PATH) }
  after { FileUtils.rm_f(TIMESTAMP_PATH) }

  context 'with mails.yml' do
    before do
      setup_mails('mails.yml')
    end

    context '#chat' do
      it 'gets a chat' do
        info = subject.chat
        info[:from].should == @mails[0][:from]
        info[:chat].should == @mails[0][:attachments][0][:content]
      end

      it 'deletes the read mail' do
        2.times do |idx|
          expect do
            info = subject.chat
            info[:from].should == @mails[idx][:from]
            info[:chat].should == @mails[idx][:attachments][0][:content]
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
          :from => 'user@email.com',
          :chat => @mails[2][:attachments][0][:content]).should == {
          'username' => '유저',
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
          :from => 'user@email.com',
          :chat => @mails[0][:attachments][0][:content]).should == {
          "username"=>"유저",
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
          :from => 'user@email.com',
          :chat => @mails[3][:attachments][0][:content]).should == {
          "username"=>"유저",
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
          :from => 'user2@email.com',
          :chat => @mails[4][:attachments][0][:content]).should == {
          "username"=>"유저2",
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
      subject.parse(subject.chat)['sms_logs'].should have(num).items
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
    ['case1.txt', 'case2.txt', 'case3.txt'].each do |fn|
      it "works with #{fn}" do
        log = File.read(File.expand_path("../fixtures/#{fn}", __FILE__))
        subject.parse(:from => 'user@email.com', :chat => log)
      end
    end
  end

  context '#username' do
    [
      ['user@email.com', '유저'],
      ['user1@email.com', '유저1'],
      ['user2@email.com', '유저2'],
      ['a@email.com', 'a@email.com'],
      ['user3@email.com', 'user3@email.com'],
      ['user@mail.com', 'user@mail.com'],
    ].each do |email, username|
      it "returns #{username} with the email address #{email}" do
        subject.username(email).should == username
      end
    end
  end

  it 'sends a mail and raises an exception with an email without attachments' do
    Mail::TestMailer.deliveries.clear
    setup_mails('mails_without_attachments.yml')
    expect do
      expect { subject.consume }.to raise_error('No Attachments')
    end.to change { Mail.all.size }.by(-1)
    Mail::TestMailer.deliveries.should have(1).items
    Mail::TestMailer.deliveries.map{|m|[m.from, m.to]}.should =~ [
        [[@mails[0][:to]], ['ermaker@gmail.com']],
      ]
  end

  it 'send two mails and raises an exception with an mail with an invalid attachment' do
    setup_mails('mails_with_invalid_attachments.yml')
    Mail.all.size.times do |idx|
      Mail::TestMailer.deliveries.clear
      expect do
        expect { subject.consume }.to raise_error
      end.to change { Mail.all.size }.by(-1)
      Mail::TestMailer.deliveries.should have(2).items
      Mail::TestMailer.deliveries.map{|m|[m.from, m.to]}.should =~ [
          [[@mails[idx][:to]], [@mails[idx][:from]]],
          [[@mails[idx][:to]], ['ermaker@gmail.com']],
        ]
    end
  end
end
