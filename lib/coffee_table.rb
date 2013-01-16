require "coffee_table/version"
require "utility"
require "redis"
require 'linguistics'
require 'rufus/scheduler'

module CoffeeTable
  class Cache

    include CoffeeTable::Utility
  
    Linguistics.use( :en )

    def initialize(options={})
      @options = options

      default_enable_cache_to true
      default_redis_namespace_to :coffee_table
      default_redis_server_to "127.0.0.1"
      default_redis_port_to 6789

      setup_redis
      @scheduler = Rufus::Scheduler.start_new
      
    end

    def get_cache(initial_key, *related_objects, &block)

      # extract the options hash if it is present
      options = {}
      if related_objects[-1].instance_of? Hash
        options = related_objects[-1]
        related_objects = related_objects[0..-2]
      end

      # check objects are valid
      related_objects.flatten.map{|o| raise "Objects passed in must have an id method" unless o.respond_to? "id"}

      # if first related_object is integer or fixnum it is used as an expiry time for the cache object
      if related_objects.empty?
        key = "#{initial_key}"
      else
        key = "#{initial_key}_#{related_objects.flatten.map{|o| "#{underscore(o.class.to_s)}[#{o.id}]"}.join("_")}"
      end
      
      if @options[:enable_cache]
        if options.has_key?(:expiry)
          expiry = options[:expiry]
        else
          expiry = nil
        end
        
        @redis.sadd "cache_keys", key unless @redis.sismember "cache_keys", key
        if @redis.exists(key)
          result = marshal_value(@redis.get(key))
        else
          result = yield
          # if its a relation, call all to get an array to cache the result
          #if result.class == ActiveRecord::Relation
          #  @logger.debug "Expanding ActiveRecord::Relation..."
          #  result = result.all
          #end
          @redis.set key, Marshal.dump(result)
          unless expiry.nil?
            @redis.expire key, expiry
            @scheduler.in "#{expiry}s" do
              @redis.srem "cache_keys", key
            end
          end
        end
      else
        unless @options[:enable_cache] && block_given?
          raise "cache is disabled and no block is given"
        else
          result = yield
        end
      end
      result
    end
  
    def expire_key(key)
      @redis.del(key)
      @redis.srem "cache_keys", key
    end
  
    def expire_all
      keys.map{|key| expire_key(key)}
    end
  
    def keys
      @redis.smembers "cache_keys"
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
        unless objects.empty?
          self.keys.each do |key|
            expire = true
            objects.each do |object|
              mod_key = "_#{key}_"
              if object.class == String
                unless mod_key.include?("_#{object}_") or mod_key.include?("_#{object.en.plural}_")
                  expire = false
                end
              else
                object_type = underscore(object.class.to_s)
                unless mod_key.include?("_#{object_type.to_sym}[#{object.id}]_") or mod_key.include?("_#{object_type.en.plural}_")
                  expire = false
                end
              end 
            end
            if expire
              expire_key(key)
              deleted_keys << key
            end
          end
        end
        deleted_keys
      end
    end
  
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
    def setup_redis
      @redis = Redis.new #::Namespace.new(options[:redis_namespace], :redis => Redis.new({:server => @options[:redis_server], :port => @options[:redis_port]}))
    end
  end
end