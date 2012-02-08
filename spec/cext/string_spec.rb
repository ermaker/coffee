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
end
