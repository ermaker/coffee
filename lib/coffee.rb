# encoding: utf-8

require 'cext/string'
require 'yaml'
require 'csv'
require 'openssl'
require 'rubygems'
require 'mail'
require 'mechanize'
require 'json'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = nil

class Coffee < Hash
  CONFIG_PATH = File.expand_path('../../config/config.yml', __FILE__)
  Mail.defaults do
    config = YAML::load(File.read(CONFIG_PATH))
    retriever_method :imap, config
  end

  def initialize(timestamp_path=nil, username_path=nil)
    super()
    @timestamp_path = timestamp_path || 'db/timestamp.yml'
    @username_path = username_path || 'db/username.yml'
    @mail_template_path = 'config/mail_template.yml'
    @username = YAML::load(File.read(@username_path))
    @mail_template = YAML::load(File.read(@mail_template_path))
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

  def chat
    mail = Mail.first(delete_after_find: true)
    return unless mail.kind_of? Mail::Message
    raw_attachment = mail.attachments.find do |a|
      a.filename == 'KakaoTalkChats.txt'
    end
    raise 'No Attachments' unless raw_attachment
    chat = raw_attachment.decoded
    return {
      :mail => mail,
      :from => mail.from.join(', '),
      :chat => chat
    } if mail.kind_of? Mail::Message
  rescue Exception => e
    Mail.deliver do
      from mail.to
      to 'ermaker@gmail.com'
      self.charset = 'utf-8'
      subject '[VodKA] [kakao tool] 메일 읽기 실패 알림'
      body <<-EOS
메일 읽기 실패
에러메세지:
#{e}
#{e.backtrace}

발신: #{mail.from}
수신: #{mail.to}
제목: #{mail.subject}
내용:
#{mail.body}
      EOS
    end if mail
    raise
  end

  def parse info
    username, log = info[:from], info[:chat]
    username = self.username(username)
    log.force_encoding('utf-8')
    log = log[1..-1] if log.start_with?("\uFEFF")
    log.delete!("\r")
    m = log.match(/\A(.*?) 님과 카카오톡 대화\n저장한 날짜 : (.*?)\n/m)
    raise 'Invalid Attachments' unless m
    receivers = [m[1]]
    if m2 = m[1].match(/\A(.*?) \(\d+명\)\z/)
      receivers = m2[1].split(', ') 
    end
    saved_date = m[2].to_time
    log = m.post_match
    log = log.split(/\n\n\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d+(?=\n)/m).reject(&:empty?)
    timestamp = Time.at(self[username, receivers]||0)
    log = log.map do |l|
      l.split(/\n(\d+년 \d+월 \d+일 (?:오전|오후) \d+:\d{1,2})/).
        reject(&:empty?).each_slice(2).drop_while do |date, sender_content|
        date.to_time < timestamp
        end.map do |date, sender_content|
        date = date.to_time
        sender, content = sender_content.split(' : ', 2)
        if content
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
        end.compact
    end.flatten
    self[username, receivers] = saved_date.to_i
    {
      'username' => username,
      'sms_logs' => log
    }
  rescue Exception => e
    Mail.deliver do
      from info[:mail].to
      to info[:mail].from
      self.charset = 'utf-8'
      subject '[VodKA] [kakao tool] 대화 내역 처리 실패 알림'
      body <<-EOS
대화 내역 처리가 실패하였습니다.
관리자가 이 내용을 처리할 예정입니다.
      EOS
    end if info[:mail]
    Mail.deliver do
      from info[:mail].to
      to 'ermaker@gmail.com'
      self.charset = 'utf-8'
      subject '[VodKA] [kakao tool] 대화 내역 처리 실패 알림'
      body <<-EOS
대화 내역 처리 실패
에러메세지:
#{e}
#{e.backtrace}

발신: #{info[:mail].from}
수신: #{info[:mail].to}
제목: #{info[:mail].subject}
내용:
#{info[:mail].body}
      EOS
    end if info[:mail]
    raise
  end

  ATTR = ['date', 'phonenumber', 'smstype', 'body', 'length']
  def consume
    while info = chat
      result = parse(info)

      CSV::open("db/#{result['username']}.csv", 'a') do |csv|
        result['sms_logs'].map{|log|ATTR.map{|attr|log[attr]}}.each do |log|
          csv << log
        end
      end

      put(result)

      pretty_result = "사용자 이름: #{result['username']}\n" +
        result['sms_logs'].map.with_index do |log,idx|
          <<-EOS
#{idx+1}번째 메세지:
    - 시각: #{log['date']}
    - 대화 참여자: #{log['phonenumber']}
    - 문자 종류: #{log['smstype'] == 'outgoing' ? '발신' : '수신'}
    - 문자 내용: #{log['body'] == 'image' ? '사진' : '문자'}
    - 메세지 길이: #{log['length']}
          EOS
        end.join
      mail_template = @mail_template
      Mail.deliver do
        from 'analyzer@hcid.kaist.ac.kr'
        to info[:from]
        self.charset = 'utf-8'
        subject mail_template[:subject]
        body mail_template[:body] + pretty_result
      end
    end
  end

  def username email
    @username.fetch(email,email)
  end

  def put log
    a = Mechanize.new
    a.post('https://virtual-possessions-staging.herokuapp.com/sms_logs', log.to_json, 'Content-type' => 'application/json')
  end
end
