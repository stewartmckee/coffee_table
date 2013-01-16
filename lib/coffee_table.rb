require "coffee_table/version"
require "redis"

module CoffeeTable
  class Cache
  
    def self.config(options)
      @options = {}

      raise "config must be passed a hash" unless options.instance_of? Hash
      @options = options
      @options[:enable_cache] = true unless @options.has_key? :enable_cache
      @options[:redis_namespace] = :coffee_table unless @options.has_key? :redis_namespace
      @options[:redis_server] = "127.0.0.1" unless @options.has_key? :redis_server
      @options[:redis_port] = 6789 unless @options.has_key? :redis_port
      
    end

    def self.get_cache(initial_key, *related_objects, &block)
      self.setup_redis

      # if first related_object is integer or fixnum it is used as an expiry time for the cache object
    
      if related_objects.empty?
        key = "#{initial_key}"
      else
        key = "#{initial_key}_#{related_objects.flatten.map{|o| "#{o.class.to_s.underscore}[#{o.id}]"}.join("_")}"
      end
      
      if @options[:enable_cache]
        # if first element is an integer or fixnum then use that as an expiry for this key
        expiry = nil
        if !related_objects.nil? and !related_objects.empty? and !related_objects.first.nil? and (related_objects.first.instance_of? Integer or related_objects.first.instance_of? Fixnum) 
          expiry = related_objects[0].to_i
          related_objects = related_objects[1..-1]
        end
        
        @redis.sadd "cache_keys", key unless @redis.sismember "cache_keys", key
        if @redis.exists(key)
          result = self.marshal_value(@redis.get(key))
        else
          result = yield
          # if its a relation, call all to get an array to cache the result
          #if result.class == ActiveRecord::Relation
          #  @logger.debug "Expanding ActiveRecord::Relation..."
          #  result = result.all
          #end
          @redis.set key, Marshal.dump(result)
          @redis.expire key expiry unless expiry.nil?
        end
      else
        result = yield
      end
      result
    end
  
    def self.expire_key(key)
      self.setup_redis
      @redis.del(key)
      @redis.srem "cache_keys", key
    end
  
    def self.expire_all
      keys.map{|key| expire_key(key)}
    end
  
    def self.keys
      self.setup_redis
      @redis.smembers "cache_keys"
    end  
  
    def self.expire_for(*objects)
      perform_caching = SiteCentral::Application.configure do
        config.action_controller.perform_caching
      end    
    
      if perform_caching
        deleted_keys = []
        unless objects.empty?
          self.keys.each do |key|
            expire = true
            objects.each do |object|
              mod_key = "_#{key}_"
              if object.class == String
                unless mod_key.include?("_#{object}_") or mod_key.include?("_#{object.pluralize}_")
                  expire = false
                end
              else
                object_type = object.class.to_s.underscore
                unless mod_key.include?("_#{object_type.to_sym}[#{object.id}]_") or mod_key.include?("_#{object_type.pluralize}_")
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
    def self.marshal_value(value)
      begin
        result = Marshal.load(value)
      rescue ArgumentError => e
        puts "Attempting to load class/module #{e.message.split(" ")[-1]}"
        e.message.split(" ")[-1].constantize
        result = self.marshal_value(value)
      end
      result
    end
    def self.setup_redis
      @redis = Redis.new #::Namespace.new(options[:redis_namespace], :redis => Redis.new({:server => @options[:redis_server], :port => @options[:redis_port]}))
    end
  end
end