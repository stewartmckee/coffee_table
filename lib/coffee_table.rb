require "coffee_table/version"
require "coffee_table/utility"
require "coffee_table/key"
require "coffee_table/invalid_object_error"
require "coffee_table/block_missing_error"
require "coffee_table/object_definition"
require "redis"
require "redis-namespace"
require 'active_support/inflector'
require 'digest/md5'
require 'gzip'
require 'active_support/hash_with_indifferent_access'

module CoffeeTable
  class Cache

    include CoffeeTable::Utility

    attr_reader :redis

    # initialize for coffee_table.  takes options to setup behaviour of cache
    def initialize(options={})
      @options = options.symbolize_keys

      default_enable_cache_to true
      default_redis_namespace_to :coffee_table
      default_redis_server_to "127.0.0.1"
      default_redis_port_to 6379
      default_redis_to nil
      default_ignore_code_changes_to false
      default_compress_content_to true
      default_compress_min_size_to 10240

      redis_client = nil
      if !@options[:redis].nil?
        redis_client = @options[:redis]
      elsif @options.has_key?(:redis_url)
        redis_client = Redis.new(:url => @options[:redis_url])
      else
        redis_client = Redis.new(:host => @options[:redis_server], :port => @options[:redis_port])
      end

      @redis = Redis::Namespace.new(@options[:redis_namespace], :redis => redis_client)
      @real_redis = redis_client

      self

    end


    def fetch(initial_key, *related_objects, &block)
      raise CoffeeTable::BlockMissingError, "No block given to generate cache from" unless block_given?

      # extract the options hash if it is present
      options = {}
      if related_objects[-1].instance_of? Hash
        options = related_objects[-1]
        related_objects = related_objects[0..-2]
      end

      # check objects are valid
      related_objects.flatten.map{|o| raise CoffeeTable::InvalidObjectError, "Objects passed in must have an id method or be a class" unless object_valid?(o)}

      if @options[:ignore_code_changes]
        block_key = ""
      else
        block_source = RubyVM::InstructionSequence.disasm(block.to_proc).to_s.gsub(/\(\s*\d+\)/, "").gsub(/^== disasm.*?$/, "")
        block_key = Digest::MD5.hexdigest(block_source)
      end
      flags = {}

      # if first related_object is integer or fixnum it is used as an expiry time for the cache object
      key = CoffeeTable::Key.new({name: initial_key, block_key: block_key, options: @options, flags: flags}, related_objects)
      if @options[:enable_cache]
        if options.has_key?(:expiry)
          expiry = options[:expiry]
        else
          expiry = nil
        end
        if keys.include?(key.to_s)
          result = marshal_value(@redis.get(key.to_s))
        else
          key.add_flag(:compressed => true)
          if keys.include?(key.to_s)
            result = marshal_value(@redis.get(key.to_s)).gunzip
          else
            key.remove_flag(:compressed)
            result = yield

            compress_result = @options[:compress_content] && result.kind_of?(String) && result.length > @options[:compress_min_size]

            if compress_result
              key.add_flag(:compressed => true)
              @redis.set(key.to_s, Marshal.dump(result.gzip))
            else
              @redis.set(key.to_s, Marshal.dump(result))
            end

            unless expiry.nil?
              @redis.expire key.to_s, expiry
            end
          end
        end
      else
        result = yield
      end
      result
    end

    def expire_key(key_value)
      keys.map{|k| CoffeeTable::Key.parse(k)}.select{|key| key.has_element?(key_value) || key.to_s == key_value }.each do |key|
        @redis.del(key.to_s)
      end
    end

    def expire_all
      keys.map{|key| expire_key(key)}
    end

    def keys
      @redis.keys
    end

    def expire_for(*objects)
      if defined? Rails
        perform_caching = Rails.application.configure do
          config.action_controller.perform_caching
        end
      else
        perform_caching = true
      end

      if perform_caching
        deleted_keys = []
        unless objects.count == 0
          keys.map{|k| CoffeeTable::Key.parse(k)}.each do |key|
            expire = true
            objects.each do |object|
              if object.class == String || object.class == Symbol
                unless key.has_element?(object)
                  expire = false
                end
              elsif object.class == Class
                object_type = underscore(object.to_s)
                unless key.has_element_type?(object_type) || key.has_element_type?(ActiveSupport::Inflector.pluralize(object_type))
                  expire = false
                end
              else
                object_type = underscore(object.class.to_s)
                unless key.has_element?("#{object_type.to_sym}[#{object.id}]") or key.has_element?(object_type)
                  expire = false
                end
              end
            end
            if expire
              expire_key(key.to_s)
              deleted_keys << key
            end
          end
        end
        deleted_keys
      end
    end

    alias :get_cache :fetch

    private
    def marshal_value(value)
      return nil if value.nil?
      begin
        # io = StringIO.new
        # io.write(value)
        # io.rewind
        result = Marshal.load(value)
      rescue ArgumentError => e
        puts "Attempting to load class/module #{e.message.split(" ")[-1]}"
        e.message.split(" ")[-1].constantize
        result = marshal_value(value)
      end
      result
    end
    def object_valid?(o)
      o.respond_to?(:id) || o.class == Class
    end
  end
end
