require 'rubygems'
require 'spork'
require 'mock_redis'
require File.expand_path(File.dirname(__FILE__) + '/../../coffee_table/spec/lib/sample_class')
require File.expand_path(File.dirname(__FILE__) + '/../../coffee_table/spec/lib/sample_class_without_id')

Spork.prefork do
  require File.expand_path(File.dirname(__FILE__) + '/../../coffee_table/lib/coffee_table.rb')
  require File.expand_path(File.dirname(__FILE__) + '/../../coffee_table/lib/coffee_table/block_missing_error.rb')
  require File.expand_path(File.dirname(__FILE__) + '/../../coffee_table/lib/coffee_table/invalid_object_error.rb')
end

Spork.each_run do
  RSpec.configure do |config|
    config.before(:each) {
      
      
      redis = mock(:redis)
      Redis.stub!(:new).and_return(MockRedis.new)
      CoffeeTable::Cache.new.expire_all
      
    }

    config.after(:each) {
    }
  end  
end



def load_sample(filename)
  File.open(File.dirname(__FILE__) + "/samples/" + filename).map { |line| line}.join("\n")  
end
def load_binary_sample(filename)
  File.open(File.dirname(__FILE__) + "/samples/" + filename, 'rb')
end

