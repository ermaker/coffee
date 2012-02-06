require 'coffee'

Mail.defaults do
  delivery_method :test
  retriever_method :test
end

describe Coffee do
  include Mail::Matchers
end
