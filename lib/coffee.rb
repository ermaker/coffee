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
end
