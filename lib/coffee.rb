# encoding: utf-8

require 'cext/string'
require 'yaml'
require 'rubygems'
require 'mail'

class Coffee < Hash
  CONFIG_PATH = File.expand_path('../../config/config.yml', __FILE__)
  Mail.defaults do
    config = YAML::load(File.read(CONFIG_PATH))
    retriever_method :imap, config
  end

  def initialize(timestamp_path=nil)
    super
    @timestamp_path = timestamp_path || 'db/timestamp.yml'
    reload
  end

  def reload
    replace(YAML::load(File.read(@timestamp_path)))
  rescue Errno::ENOENT
    open(@timestamp_path, 'w') do |f|
      f << {}.to_yaml
    end
    retry
  end

  def flush
    open(@timestamp_path, 'w') do |f|
      f << Hash[self].to_yaml
    end
  end

  alias old_get []
  alias old_set []=

  def []= username, receivers, time
    old_set([username, receivers], time)
    flush
  end

  def [] username, receivers
    old_get([username, receivers])
  end

  def chat_log
    mail = Mail.first(delete_after_find: true)
    mail.attachments.find {|a|a.filename == 'KakaoTalkChats.txt'}.decoded if mail.kind_of? Mail::Message
  end

  def parse username, log
    m = log.match(/\A(.*?) 님과 카카오톡 대화\n저장한 날짜 : (.*?)\n/m)
    receivers = [m[1]]
    if m2 = m[1].match(/\A(.*?) \(\d+명\)\z/)
      receivers = m2[1].split(', ') 
    end
    saved_date = m[2].to_time
    log = m.post_match
    log = log.split(/\n\n\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d+(?=\n)/m).reject(&:empty?)
    timestamp = Time.at(self[username, receivers]||0)
    log = log.map do |l|
      l.split(/\n(\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d+)/).
        reject(&:empty?).each_slice(2).drop_while do |date, sender_content|
        date.to_time < timestamp
        end.map do |date, sender_content|
        date = date.to_time
        sender, content = sender_content.split(' : ', 2)
        content.chomp!
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
    self[username, receivers] = saved_date.to_i
    {
      'username' => username,
      'sms_logs' => log
    }
  end
end
