# encoding: utf-8

require 'yaml'
require 'rubygems'
require 'mail'

class Coffee
  CONFIG_PATH = File.expand_path('../../config/config.yml', __FILE__)
  Mail.defaults do
    config = YAML::load(File.read(CONFIG_PATH))
    retriever_method :imap, config
  end

  def chat_log
    Mail.first(delete_after_find: true).attachments.find {|a|a.filename == 'KakaoTalkChats.txt'}.decoded
  end

  def parse log
    m = log.match(/\A(.*?)님과 카카오톡 대화\n저장한 날짜 : (.*?)\n/m)
    receiver = m[1].strip
    #saved_date = m[2]
    log = m.post_match
    log = log.split(/\n\n\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d+(?=\n)/m).reject(&:empty?)
    log = log.map do |l|
      l.split(/\n(\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d+)/).
        reject(&:empty?).each_slice(2).map do |date, sender_content|
        m = date.match(/(\d+)년 (\d+)월 (\d+)일 (오전|오후) (\d+):(\d+)/)
        date = Time.new(
          m[1].to_i,
          m[2].to_i,
          m[3].to_i,
          m[5].to_i + (m[4] == '오전' ? 0 : 12),
          m[6].to_i)
        sender, content = sender_content.split(' : ', 2)
        {
          'length' => content.bytesize,
          'smstype' => sender == '회원님' ? 'outgoing' : 'incoming',
          'body' => content == '<사진>' ? 'image' : 'text',
          'phonenumber' => sender == '회원님' ? receiver : sender,
          'date' => date.strftime('%F %T'),
          'contact_id' => -1,
          'thread_id' => -1,
        }
        end
    end.flatten
    {
      'username' => 'kakaotest',
      'sms_logs' => log
    }
  end
end
