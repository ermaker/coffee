# encoding: utf-8

require 'spec_helper'
require 'cext/string'

describe String do
  it '#self? works' do
    '회원님'.should be_self
    '이민우'.should_not be_self
  end

  it '#image? works' do
    '<사진>'.should be_image
    'ㅋ'.should_not be_image
  end

  it '#to_time works' do
    '2012년 2월 8일 오후 1:11'.to_time.strftime("%F %T").should == '2012-02-08 13:11:00'
    '1970년 1월 1일 오전 12:0'.to_time == Time.at(0)
    '1970년 1월 1일 오전 12:1'.to_time == Time.at(60)
    '2012년 1월 10일 오후 12:15'.to_time.strftime("%F %T").should == '2012-01-10 12:15:00'
  end
end
