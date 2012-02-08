# encoding: utf-8

class String
  def self?
    self == '회원님'
  end

  def image?
    self == '<사진>'
  end

  def to_time
    m = self.match(/(\d+)년 (\d+)월 (\d+)일 (오전|오후) (\d+):(\d+)/)
    return Time.new(
      m[1].to_i,
      m[2].to_i,
      m[3].to_i,
      m[5].to_i + (m[4] == '오전' ? 0 : 12),
      m[6].to_i)
  end
end
