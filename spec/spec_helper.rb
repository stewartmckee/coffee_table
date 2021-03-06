require 'rubygems'
require 'bundler/setup'

require 'coveralls'
Coveralls.wear!

require 'digest/md5'
require 'spork'
# require 'mock_redis'
require File.expand_path(File.dirname(__FILE__) + '/../spec/lib/sample_class.rb')
require File.expand_path(File.dirname(__FILE__) + '/../spec/lib/sample_class_without_id.rb')


Spork.prefork do
  require File.expand_path(File.dirname(__FILE__) + '/../lib/coffee_table.rb')
  require File.expand_path(File.dirname(__FILE__) + '/../lib/coffee_table/block_missing_error.rb')
  require File.expand_path(File.dirname(__FILE__) + '/../lib/coffee_table/invalid_object_error.rb')
  require File.expand_path(File.dirname(__FILE__) + '/../lib/coffee_table/key.rb')
end

Spork.each_run do
  RSpec.configure do |config|
    config.before(:each) {

      redis = CoffeeTable::Cache.new.redis
      redis.keys.map{|k| redis.del k }

    }

    config.after(:each) {
      # CoffeeTable::Cache.new.expire_all
    }
  end
end

def load_sample(filename)
  File.open(File.dirname(__FILE__) + "/samples/" + filename).map { |line| line}.join("\n")
end
def load_binary_sample(filename)
  File.open(File.dirname(__FILE__) + "/samples/" + filename, 'rb')
end

def md5_block(&block)
  block_source = RubyVM::InstructionSequence.disasm(block.to_proc).to_s.gsub(/\(\s*\d+\)/, "").gsub(/^== disasm.*?$/, "")
  Digest::MD5.hexdigest(block_source)
end
