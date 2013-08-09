module CoffeeTable
  module Utility

    
    # used for setting default options
    def method_missing(method_sym, *arguments, &block)
      if method_sym.to_s =~ /^default_(.*)_to$/
        tag_name = method_sym.to_s.split("_")[1..-2].join("_").to_sym
        @options[tag_name] = arguments[0] unless @options.has_key?(tag_name)
      else
        super
      end
    end

    def underscore(text)
      text.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
    end
  end
end