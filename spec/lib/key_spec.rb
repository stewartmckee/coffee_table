require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CoffeeTable::Key do
  
  context "has correct methods" do
    it "should have a parse class method" do
      CoffeeTable::Key.should respond_to :parse
    end
    it "should have a has_element? instance method" do
      CoffeeTable::Key.new("name", "key").should respond_to :has_element?
    end
    it "should have a has_element_type? instance method" do
      CoffeeTable::Key.new("name", "key").should respond_to :has_element_type?
    end
  end

  context "parsing a string" do
    it "should parse a string into its elements" do
      key = CoffeeTable::Key.parse("test|asdf|sample_class")


      key.elements.count.should == 1
      key.name.should == "test"
      key.code_hash.should == "asdf"
      key.elements[0].should == "sample_class"

    end
    it "should decode encoded elements" do
      key = CoffeeTable::Key.parse("te&#124;s&amp;t|asdf&#124;s&amp;|sample_&#124;s&amp;class")


      key.elements.count.should == 1
      key.name.should == "te|s&t"
      key.code_hash.should == "asdf|s&"
      key.elements[0].should == "sample_|s&class"
    end
    it "should encode the key data" do

      key = CoffeeTable::Key.new("te|s&t", "asdf|s&", "sample_|s&class")

      key.name.should == "te|s&t"
      key.code_hash.should == "asdf|s&"
      key.elements[0].should == "sample_|s&class"

      key.to_s.should == "te&#124;s&amp;t|asdf&#124;s&amp;|sample_&#124;s&amp;class"
    
    end
  end

  context "matching keys" do
    it "should match a key on its name" do
      key = CoffeeTable::Key.new("name", "key", "value", ["value1", "value2"])
      key.has_element?("name").should be_true
      key.has_element?("key").should be_false
    end
    it "should match a key on its data" do
      key = CoffeeTable::Key.new("name", "key", "value", ["value1", "value2"])
      key.has_element?("key").should be_false
      key.has_element?("value").should be_true
      key.has_element?("value1").should be_true
      key.has_element?("value2").should be_true
    end
    it "should match a key on a class type" do
      key = CoffeeTable::Key.new("name", "key", "sample_class[3]", ["value1", "value2"])
      key.has_element?("key").should be_false
      key.has_element_type?("sample_class").should be_true
    end
  end
end