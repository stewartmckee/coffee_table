module CoffeeTable
  class ObjectDefinition

    def initialize(klass, id)
      @klass = klass
      @id = id
    end

    def self.from_hash(hash)
      hash.map {|k, v| ObjectDefinition.new(k, v)}
    end

    def to_s
      "#{klass.to_s)}[#{@id.to_s}]"
    end

  end
end