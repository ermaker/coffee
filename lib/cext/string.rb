# encoding: utf-8
require 'active_support/core_ext'

class String
  def self?
    self == '회원님'
  end

  def image?
    self == '<사진>'
  end

  def to_time
    m = self.match(/(\d+)년 (\d+)월 (\d+)일 (오전|오후) (\d+):(\d+)/)
    raise 'Invalid Time Format' unless m
    return Time.parse("#{m[1]}-#{m[2]}-#{m[3]} #{m[5]}:#{m[6]}:00 #{m[4] == '오전' ? 'am' : 'pm'}")
  end
end
