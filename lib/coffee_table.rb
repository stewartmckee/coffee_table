require "coffee_table/version"
require "coffee_table/utility"
require "coffee_table/key"
require "coffee_table/invalid_object_error"
require "coffee_table/block_missing_error"
require "coffee_table/object_definition"
require "redis"
require 'rufus/scheduler'
require 'active_support/inflector'
require 'digest/md5'
require 'gzip'

module CoffeeTable
  class Cache

    include CoffeeTable::Utility


    # initialize for coffee_table.  takes options to setup behaviour of cache
    def initialize(options={})
      @options = options

      default_enable_cache_to true
      default_redis_namespace_to :coffee_table
      default_redis_server_to "127.0.0.1"
      default_redis_port_to 6379
      default_ignore_code_changes_to false
      default_compress_content_to true
      default_compress_min_size_to 10240
      default_max_threads_to 28

      rufus_version = Gem::Version.new(Rufus::Scheduler::VERSION)
      if rufus_version >= Gem::Version.new('3.0.0')
        @scheduler = Rufus::Scheduler.new(:max_work_threads => @options[:max_threads])
      else
        @scheduler = Rufus::Scheduler.start_new
      end
    end

    def fetch(initial_key, *related_objects, &block)
      raise CoffeeTable::BlockMissingError, "No block given to generate cache from" unless block_given?

      @redis = get_redis

      # extract the options hash if it is present
      options = {}
      if related_objects[-1].instance_of? Hash
        options = related_objects[-1]
        related_objects = related_objects[0..-2]
      end

      # check objects are valid
      related_objects.flatten.map{|o| raise CoffeeTable::InvalidObjectError, "Objects passed in must have an id method or be a class" unless object_valid?(o)}

      # if @options[:ignore_code_changes]
        block_key = ""
      # else
      #   block_key = Digest::MD5.hexdigest(block.to_source)
      # end

      flags = {}



      # if first related_object is integer or fixnum it is used as an expiry time for the cache object
      key = CoffeeTable::Key.new(initial_key, block_key, flags, related_objects)

      if @options[:enable_cache]
        if options.has_key?(:expiry)
          expiry = options[:expiry]
        else
          expiry = nil
        end

        @redis.sadd "cache_keys", key unless @redis.sismember "cache_keys", key.to_s
        if @redis.exists(key.to_s)
          if key.options[:compressed]
            result = marshal_value(@redis.get(key.to_s).gunzip)
          else
            result = marshal_value(@redis.get(key.to_s))
          end
        else
          result = yield

          compress_result = @options[:compress_content] && result.kind_of?(String) && result.length > @options[:compress_min_size]

          if compress_result
            key.add_flag(:compressed => true)
            @redis.set key.to_s, Marshal.dump(result.gzip)
          else
            @redis.set key.to_s, Marshal.dump(result)
          end

          unless expiry.nil?
            @redis.expire key.to_s, expiry
            @scheduler.in "#{expiry}s" do
              @redis.srem "cache_keys", key.to_s
            end
          end
        end
      else
        result = yield
      end

      @redis.close
      result
    end

    def expire_key(key_value)
      @redis = get_redis
      keys.map{|k| CoffeeTable::Key.parse(k)}.select{|key| key.has_element?(key_value) || key.to_s == key_value }.each do |key|
        @redis.del(key.to_s)
        @redis.srem "cache_keys", key.to_s
      end
      @redis.close
    end

    def expire_all
      keys.map{|key| expire_key(key)}
    end

    def keys
      @redis = get_redis
      members = @redis.smembers("cache_keys")
      @redis.close
      memberss
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
      begin
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
    def get_redis
      if @options.has_key?(:redis_url)
        return Redis.new({:url => @options[:redis_url]})
      else
        return Redis.new({:server => @options[:redis_server], :port => @options[:redis_port]})
      end
    end
  end
end
