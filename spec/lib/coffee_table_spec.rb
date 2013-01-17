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
      lambda{CoffeeTable::Cache.new}.should_not raise_exception CoffeeTableBlockMissingError
    end
  end
  
  describe "get_cache" do
    it "should raise an exception when block not given" do
      lambda{@coffee_table.get_cache("asdf")}.should raise_exception CoffeeTableBlockMissingError
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
        test_object = SampleClass.new(9938)
        result = @coffee_table.get_cache(:test_key, test_object) do
          "this is a changed value"
        end
        
        @coffee_table.keys.should include "test_key_sample_class[9938]"
        
      end
      it "should raise an exception if a related object does not respond_to id" do
        test_object = SampleClassWithoutId.new

        lambda {
          result = @coffee_table.get_cache(:test_key, test_object) do
            "this is a changed value"
          end
        }.should raise_exception CoffeeTableInvalidObjectError, "Objects passed in must have an id method or be a class"
        
      end

      it "should create a universal key if the objects passed in are an uninitialised class" do
        result = @coffee_table.get_cache(:test_key, SampleClass) do
          "this is a changed value"
        end
        
        @coffee_table.keys.should include "test_key_sample_classes"          
      end

    end
    context "with expiry" do
      it "keys should update when cache expires" do
        @coffee_table.get_cache(:test_key, :expiry => 0.2) do
          "object1"
        end
        @coffee_table.keys.count.should == 1
        sleep 0.5
        @coffee_table.keys.count.should == 0
      end
      it "should not execute block during cache period" do
        @coffee_table.get_cache("asdf", :expiry => 1) do
          "this is a value"
        end
        result = @coffee_table.get_cache("asdf") do
          "this is a changed value"
        end      
        result.should == "this is a value"      

      end
      it "should execute block and return value when cache has expired" do
        @coffee_table.get_cache("asdf", :expiry => 1) do
          "this is a value"
        end
        sleep 2
        result = @coffee_table.get_cache("asdf") do
          "this is a changed value"
        end      
        result.should == "this is a changed value"      
      end
    end
  end
  
  describe "expire_key" do
    it "should expire the specified key" do
      @coffee_table.get_cache(:first_key) do
        "object1"
      end
      @coffee_table.get_cache(:second_key) do
        "object2"
      end
      @coffee_table.get_cache(:third_key) do
        "object3"
      end

      @coffee_table.keys.sort.should == ["first_key", "second_key", "third_key"].sort
      @coffee_table.expire_key("second_key")
      @coffee_table.keys.sort.should == ["first_key", "third_key"].sort

    end
    it "should not expire anything if no matches" do
      @coffee_table.get_cache(:first_key) do
        "object1"
      end
      @coffee_table.get_cache(:second_key) do
        "object2"
      end
      @coffee_table.get_cache(:third_key) do
        "object3"
      end

      @coffee_table.keys.sort.should == ["first_key", "second_key", "third_key"].sort
      @coffee_table.expire_key("fourth_key")
      @coffee_table.keys.sort.should == ["first_key", "second_key", "third_key"].sort

    end
  end
  
  describe "expire_all" do
    before(:each) do
      object1 = [SampleClass.new(1), SampleClass.new(2), SampleClass.new(3)]
      object2 = [SampleClass.new(4), SampleClass.new(2), SampleClass.new(5)]
      object3 = [SampleClass.new(7), SampleClass.new(2), SampleClass.new(8)]

      @coffee_table.get_cache(:first_key) do
        "object1"
      end
      @coffee_table.get_cache(:second_key) do
        "object2"
      end
      @coffee_table.get_cache(:third_key) do
        "object3"
      end
    end

    it "should delete all keys" do
      @coffee_table.keys.count.should == 3
      @coffee_table.expire_all
      @coffee_table.keys.count.should == 0

      result = @coffee_table.get_cache(:first_key) do
        "changed value"
      end

      result.should == "changed value"

    end
  end
  
  describe "keys" do
    before(:each) do
      @object1 = [SampleClass.new(1), SampleClass.new(2), SampleClass.new(3)]
      @object2 = [SampleClass.new(4), SampleClass.new(2), SampleClass.new(5)]
      @object3 = [SampleClass.new(7), SampleClass.new(2), SampleClass.new(8)]

    end

    it "should return an array of string" do
      @coffee_table.keys.should be_an_instance_of Array
      @coffee_table.keys.map{|key| key.should be_an_instance_of String}
    end
    it "should return key created without objects" do
      @coffee_table.get_cache(:first_key) do
        "object1"
      end
      @coffee_table.get_cache(:second_key) do
        "object2"
      end
      @coffee_table.get_cache(:third_key) do
        "object3"
      end

      @coffee_table.keys.sort.should == ["first_key",
                               "second_key",
                               "third_key"].sort

    end
    it "should return key created with objects and ids" do
      @coffee_table.get_cache(:first_key, @object1) do
        "object1"
      end
      @coffee_table.get_cache(:second_key, @object2) do
        "object2"
      end
      @coffee_table.get_cache(:third_key, @object3) do
        "object3"
      end
      @coffee_table.keys.sort.should == ["first_key_sample_class[1]_sample_class[2]_sample_class[3]",
                               "second_key_sample_class[4]_sample_class[2]_sample_class[5]",
                               "third_key_sample_class[7]_sample_class[2]_sample_class[8]"].sort
    end

  end
  
  describe "expire_for" do
    before(:each) do
      object1 = [SampleClass.new(1), SampleClass.new(2), SampleClass.new(3)]
      object2 = [SampleClass.new(4), SampleClass.new(2), SampleClass.new(5)]
      object3 = [SampleClass.new(7), SampleClass.new(2), SampleClass.new(8)]

      @coffee_table.get_cache(:first_key, object1) do
        "object1"
      end
      @coffee_table.get_cache(:second_key, object2) do
        "object2"
      end
      @coffee_table.get_cache(:third_key, object3) do
        "object3"
      end
    end

    it "should not delete any keys if object is not present" do
      @coffee_table.keys.count.should == 3
      @coffee_table.expire_for(SampleClass.new(18))
      @coffee_table.keys.count.should == 3
    end
    it "should only delete keys that object is present in" do
      @coffee_table.keys.count.should == 3
      @coffee_table.expire_for(SampleClass.new(1))
      @coffee_table.keys.count.should == 2
    end

    it "should delete a key if the object is at the end of they key" do
      @coffee_table.keys.count.should == 3
      @coffee_table.expire_for(SampleClass.new(3))
      @coffee_table.keys.count.should == 2
    end

    it "should expire all keys relating to a class if uninitialised class is passed in" do
      @coffee_table.get_cache(:fourth_key) do
        "object4"
      end
      @coffee_table.keys.count.should == 4
      @coffee_table.expire_for(SampleClass)
      @coffee_table.keys.count.should == 1
    end
  end
    
end