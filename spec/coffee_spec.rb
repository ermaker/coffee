# encoding: cp949

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
end
