require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CoffeeTable do
  

  specify { CoffeeTable::Cache.should respond_to :config}
  specify { CoffeeTable::Cache.should respond_to :get_cache}
  specify { CoffeeTable::Cache.should respond_to :expire_key}
  specify { CoffeeTable::Cache.should respond_to :expire_all}
  specify { CoffeeTable::Cache.should respond_to :keys}
  specify { CoffeeTable::Cache.should respond_to :expire_for}
  
  before(:each) do

    @coffee_table = CoffeeTable::Cache.new
    
  end
  
  describe "config" do
    it "should take a hash for config" do
      CoffeeTable::Cache.config({:test => "asdf"})
    end
    it "should raise exception when hash not given" do
      lambda{CoffeeTable::Cache.config(9)}.should raise_exception "config must be passed a hash"
    end
  end
  
  describe "get_cache" do
    it "should raise an exception when block not given" do
      lambda{CoffeeTable::Cache.get_cache("asdf")}.should raise_exception "no block given (yield)"
    end
    it "should not raise an exception if cache value is available and no block given" do
      result = CoffeeTable::Cache.get_cache("test_key") do
        "this is a valid result"
      end
      
      CoffeeTable::Cache.get_cache("test_key").should == "this is a valid result"
    end
    it "should execute block when cache value not available" do
      result = CoffeeTable::Cache.get_cache("asdf") do
        "this is a value"
      end
      
      result.should == "this is a value"      
    end
    it "should return cached value when cache available" do
      CoffeeTable::Cache.get_cache("asdf") do
        "this is a value"
      end
      result = CoffeeTable::Cache.get_cache("asdf") do
        "this is a changed value"
      end
        
      result.should == "this is a value"      
      
    end
    it "should execute block when store not available" do
      CoffeeTable::Cache.get_cache(:test_key) do
        TESTVAR = "testvar"
        "this is a value"
      end
      CoffeeTable::Cache.get_cache(:test_key) do
        TESTVAR = "testvar2"
        "this is a value"
      end
      
      TESTVAR.should == "testvar"
      
    end
    context "without related objects" do
      it "should create a key with just the initial key" do        
        result = CoffeeTable::Cache.get_cache(:test_key) do
          "this is a changed value"
        end
        
        CoffeeTable::Cache.keys.should include "test_key"
        
      end
    end
    context "with related objects" do
      it "should create a key from the id's of the related objects" do
        test_object = {}
        result = CoffeeTable::Cache.get_cache(:test_key, test_object) do
          "this is a changed value"
        end
        
        CoffeeTable::Cache.keys.should include "test_key"
        
      end
      it "should raise an exception if a related object is not an instance of active model"
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