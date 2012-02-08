# encoding: utf-8

require 'cext/string'
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

  def parse username, log
    m = log.match(/\A(.*?) 님과 카카오톡 대화\n저장한 날짜 : (.*?)\n/m)
    receivers = [m[1]]
    if m2 = m[1].match(/\A(.*?) \(\d+명\)\z/)
      receivers = m2[1].split(', ') 
    end
    #saved_date = m[2]
    log = m.post_match
    log = log.split(/\n\n\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d+(?=\n)/m).reject(&:empty?)
    log = log.map do |l|
      l.split(/\n(\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d+)/).
        reject(&:empty?).each_slice(2).map do |date, sender_content|
        date = date.to_time
        sender, content = sender_content.split(' : ', 2)
        {
          'length' => content.bytesize,
          'smstype' => sender.self? ? 'outgoing' : 'incoming',
          'body' => content.image? ? 'image' : 'text',
          'phonenumber' => sender.self? ?
          receivers.join(', ') :
          (receivers - [sender]).unshift(sender).join(', '),
          'date' => date.strftime('%F %T'),
          'contact_id' => -1,
          'thread_id' => -1,
        }
        end
    end.flatten
    {
      'username' => username,
      'sms_logs' => log
    }
  end
end
