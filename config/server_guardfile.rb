guard 'shell' do
  watch(%r{^.*$}) do
    system(%{bundle exec ruby -Ilib -rcoffee -e "Coffee.new.consume"})
    puts
  end
end
