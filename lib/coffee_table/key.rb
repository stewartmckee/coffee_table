require "coffee_table/utility"

module CoffeeTable
  class Key
    include CoffeeTable::Utility

    def self.parse(string)
      elements = string.split("|").map{|e| decode_element(e) }
      key = Key.new(elements[0], elements[1])
      key.elements =  elements[2..-1]
      key
    end

    def initialize(name, block_key, *objects)
      @name = name
      @block_key = block_key
      @elements = objects.flatten.map{|o| key_for_object(o)}
    end

    def has_element?(element)
      matches?(element.to_s)
    end

    def has_element_type?(element)
      matches?(element.to_s + "[", :match => :start)
    end

    def name
      @name
    end

    def code_hash
      @block_key
    end

    def elements
      @elements
    end

    def elements=(elements)
      @elements = elements
    end

    def <=>(o)
      self.to_s <=> o.to_s
    end

    def to_s
      [encode_element(@name), encode_element(@block_key), @elements.map{|e| encode_element(e) }].flatten.join("|")
    end

    private

    def matches?(fragment, options={})
      if options[:match] == :start
        @name == fragment || !@elements.select{|e| e =~ /^#{Regexp.escape(fragment)}/ }.empty?
      else
        @name == fragment || @elements.include?(fragment)
      end
    end

    def encode_element(element)
      element.to_s.gsub("&", "&amp;").gsub("|", "&#124;")
    end

    def self.decode_element(element)
      element.to_s.gsub("&#124;", "|").gsub("&amp;", "&")
    end

    def key_for_object(o)
      if o.class == Class
        "#{ActiveSupport::Inflector.pluralize(underscore(o.to_s))}"
      elsif o.kind_of?(String) || o.kind_of?(Symbol)
        "#{underscore(o.to_s)}"
      else
        "#{underscore(o.class.to_s)}[#{o.id}]"
      end
    end
  end
end