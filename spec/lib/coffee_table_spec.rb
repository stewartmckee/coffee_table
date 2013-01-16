require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CoffeeTable do
  
  before(:each) do
    @coffee_table = CoffeeTable::Cache.new
  end
  
  specify { CoffeeTable::Cache.should respond_to :new}
  specify { @coffee_table.should respond_to :get_cache}
  specify { @coffee_table.should respond_to :expire_key}
  specify { @coffee_table.should respond_to :expire_all}
  specify { @coffee_table.should respond_to :keys}
  specify { @coffee_table.should respond_to :expire_for}
  
  describe "config" do
    it "should take a hash for config" do
      CoffeeTable::Cache.new({:test => "asdf"})
    end
    it "should not raise exception when hash not given" do
      lambda{CoffeeTable::Cache.new}.should_not raise_exception
    end
  end
  
  describe "get_cache" do
    it "should raise an exception when block not given" do
      lambda{@coffee_table.get_cache("asdf")}.should raise_exception "no block given (yield)"
    end
    it "should not raise an exception if cache value is available and no block given" do
      result = @coffee_table.get_cache("test_key") do
        "this is a valid result"
      end
      
      @coffee_table.get_cache("test_key").should == "this is a valid result"
    end
    it "should execute block when cache value not available" do
      result = @coffee_table.get_cache("asdf") do
        "this is a value"
      end
      
      result.should == "this is a value"      
    end
    it "should return cached value when cache available" do
      @coffee_table.get_cache("asdf") do
        "this is a value"
      end
      result = @coffee_table.get_cache("asdf") do
        "this is a changed value"
      end
        
      result.should == "this is a value"      
      
    end
    it "should execute block when store not available" do
      @coffee_table.get_cache(:test_key) do
        TESTVAR = "testvar"
        "this is a value"
      end
      @coffee_table.get_cache(:test_key) do
        TESTVAR = "testvar2"
        "this is a value"
      end
      
      TESTVAR.should == "testvar"
      
    end
    context "without related objects" do
      it "should create a key with just the initial key" do        
        result = @coffee_table.get_cache(:test_key) do
          "this is a changed value"
        end
        
        @coffee_table.keys.should include "test_key"
        
      end
    end
    context "with related objects" do
      it "should create a key from the id's of the related objects" do
        test_object = SampleClass.new
        result = @coffee_table.get_cache(:test_key, test_object) do
          "this is a changed value"
        end
        
        puts @coffee_table.keys
        @coffee_table.keys.should include "test_key_sample_class[9939]"
        
      end
      it "should raise an exception if a related object does not respond_to id" do
        test_object = SampleClassWithoutId.new

        lambda {
        result = @coffee_table.get_cache(:test_key, test_object) do
          "this is a changed value"
        end
        }.should raise_exception "Objects passed in must have an id method"
        
      end
    end
    context "with expiry" do
      it "should not execute block when cache available and not expired"
      it "should execute block and return value when cache has expired"
    end
  end
  
  describe "expire_key" do
  end
  
  describe "expire_all" do
  end
  
  describe "keys" do
  end
  
  describe "expire_for" do
  end
    
end