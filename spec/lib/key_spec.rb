require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CoffeeTable::Key do

  context "has correct methods" do
    it "should have a parse class method" do
      expect(CoffeeTable::Key).to respond_to :parse
    end
    it "should have a has_element? instance method" do
      expect(CoffeeTable::Key.new(name: "name", block_key: "key")).to respond_to :has_element?
    end
    it "should have a has_element_type? instance method" do
      expect(CoffeeTable::Key.new(name: "name", block_key: "key")).to respond_to :has_element_type?
    end
  end

  context "parsing a string" do
    it "should parse a string into its elements" do
      key = CoffeeTable::Key.parse("test|asdf|sample_class|")


      expect(key.elements.count).to eq 1
      expect(key.name).to eq "test"
      expect(key.code_hash).to eq "asdf"
      expect(key.elements[0]).to eq "sample_class"

    end
    it "should decode encoded elements" do
      key = CoffeeTable::Key.parse("te&#124;s&amp;t|asdf&#124;s&amp;|sample_&#124;s&amp;class|")


      expect(key.elements.count).to eq 1
      expect(key.name).to eq "te|s&t"
      expect(key.code_hash).to eq "asdf|s&"
      expect(key.elements[0]).to eq "sample_|s&class"
    end
    it "should encode the key data" do

      key = CoffeeTable::Key.new({name: "te|s&t", block_key: "asdf|s&"}, "sample_|s&class")

      expect(key.name).to eq "te|s&t"
      expect(key.code_hash).to eq "asdf|s&"
      expect(key.elements[0]).to eq "sample_|s&class"

      expect(key.to_s).to eq "te&#124;s&amp;t|asdf&#124;s&amp;|sample_&#124;s&amp;class|"

    end
  end

  context "matching keys" do
    it "should match a key on its name" do
      key = CoffeeTable::Key.new({name: "name", block_key: "key"}, "value", ["value1", "value2"])
      expect(key.has_element?("name")).to be_truthy
      expect(key.has_element?("key")).to be_falsey
    end
    it "should match a key on its data" do
      key = CoffeeTable::Key.new({name: "name", block_key: "key"}, "value", ["value1", "value2"])
      expect(key.has_element?("key")).to be_falsey
      expect(key.has_element?("value")).to be_truthy
      expect(key.has_element?("value1")).to be_truthy
      expect(key.has_element?("value2")).to be_truthy
    end
    it "should match a key on a class type" do
      key = CoffeeTable::Key.new({name: "name", block_key: "key"}, "sample_class[3]", ["value1", "value2"])
      expect(key.has_element?("key")).to be_falsey
      expect(key.has_element_type?("sample_class")).to be_truthy
    end
  end

  context "storing options" do

    before(:each) do
      @obj1 = CoffeeTable::ObjectDefinition.new(:test, 1)
      @obj2 = CoffeeTable::ObjectDefinition.new(:test, 2)
      @obj3 = CoffeeTable::ObjectDefinition.new(:test, 3)
    end

    it "should encode options into key" do
      key = CoffeeTable::Key.new(name: "name", block_key: "key", flags: {:option => "value", :option2 => "value2"})
      expect(key.to_s).to eql "name|key|option=value&amp;option2=value2"
    end
    it "should parse back options out of key" do
      key = CoffeeTable::Key.parse("name|block|key=value")
      expect(key.flags).to eql ({:key => "value"})

    end
    it "should handle no options" do
      key = CoffeeTable::Key.new(name: "name", block_key: "key")
      expect(key.to_s).to eql "name|key|"
    end

    it "should handle one option" do
      key = CoffeeTable::Key.new(name: "name", block_key: "key", flags: {:option => "value"})
      expect(key.to_s).to eql "name|key|option=value"
    end
    it "should handle multiple options" do
      key = CoffeeTable::Key.new(name: "name", block_key: "key", flags: {:option => "value", :option2 => "value2"})
      expect(key.to_s).to eql "name|key|option=value&amp;option2=value2"
    end

    it "matches regardless of flags" do
      key = CoffeeTable::Key.new({name: "name", block_key: "key", flgas: {:option => "value", :option2 => "value2"}}, @obj1, @obj2, @obj3)
      expect(key.has_element?("test[1]")).to be_truthy
      expect(key.has_element?("test[2]")).to be_truthy
      expect(key.has_element?("test[3]")).to be_truthy
      expect(key.has_element?("test[4]")).to be_falsey
    end

    it "does not match on flag values" do
      key = CoffeeTable::Key.new({name: "name", block_key: "key", flags: {:option => "value", :option2 => "value2"}}, @obj1, @obj2, @obj3)
      expect(key.has_element?("option=value&amp;option2=value2")).to be_falsey

    end

  end
end
