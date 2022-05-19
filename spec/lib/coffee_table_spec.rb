require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require "base64"
describe CoffeeTable::Cache do

  before(:each) do
    @coffee_table = CoffeeTable::Cache.new
  end

  specify { expect(CoffeeTable::Cache).to respond_to :new}
  specify { expect(@coffee_table).to respond_to :fetch}
  specify { expect(@coffee_table).to respond_to :expire_key}
  specify { expect(@coffee_table).to respond_to :expire_all}
  specify { expect(@coffee_table).to respond_to :keys}
  specify { expect(@coffee_table).to respond_to :expire_for}

  describe "config" do
    it "should take a hash for config" do
      CoffeeTable::Cache.new({:test => "asdf"})
    end
    it "should not raise exception when hash not given" do
      lambda{CoffeeTable::Cache.new}.should_not raise_exception
    end
  end

  describe "fetch" do
    it "should raise an exception when block not given" do
      lambda{@coffee_table.fetch("asdf")}.should raise_exception CoffeeTable::BlockMissingError
    end
    it "should execute block when cache value not available" do
      result = @coffee_table.fetch("asdf") do
        "this is a value"
      end

      expect(result).to eq "this is a value"
    end
    it "should return cached value when cache available" do
      value = "this is a value"
      @coffee_table.fetch("asdf") do
        value
      end
      value = "this is a changed value"
      result = @coffee_table.fetch("asdf") do
        value
      end

      expect(result).to eq "this is a value"

    end

    context "compressing" do

      before(:each) do
        @redis = Redis::Namespace.new("coffee_table", :redis => Redis.new)
      end

      it "compresses on strings greater than limit" do
        @coffee_table = CoffeeTable::Cache.new(:server => "127.0.0.1", :port => 6379, :compress_min_size => 20)
        zipped_content = "this string should be long".gzip
        result = @coffee_table.fetch(:test_key) do
          "this string should be long"
        end
        expect(result).to eql "this string should be long"
        puts "asdf"
        @redis.get("test_key|009e2965832e67d06fb9a1b667cc1aca|compressed=true").should start_with "\u0004"
      end
      it "does not compress on non strings" do
        @coffee_table = CoffeeTable::Cache.new(:server => "127.0.0.1", :port => 6379, :compress_min_size => 20)
        result = @coffee_table.fetch(:test_key) do
          {:test => "this value is a decent length to trigger compress"}
        end
        expect(result).to eql ({:test => "this value is a decent length to trigger compress"})
        Base64.encode64(@redis.get("test_key|8c3fde43e56b71d90843b9555673e120|")).should eql "BAh7BjoJdGVzdEkiNnRoaXMgdmFsdWUgaXMgYSBkZWNlbnQgbGVuZ3RoIHRv\nIHRyaWdnZXIgY29tcHJlc3MGOgZFVA==\n"
      end

      it "does not compress when turned off" do
        @coffee_table = CoffeeTable::Cache.new(:server => "127.0.0.1", :port => 6379, :compress_content => false)
        result = @coffee_table.fetch(:test_key) do
          "this string should be long"
        end
        expect(result).to eql "this string should be long"
        @redis.get("test_key|009e2965832e67d06fb9a1b667cc1aca|").should eql Marshal.dump("this string should be long")
      end
      it "does not compress on strings below limit" do
        @coffee_table = CoffeeTable::Cache.new(:server => "127.0.0.1", :port => 6379, :compress_min_size => 20)
        result = @coffee_table.fetch(:test_key) do
          "short"
        end
        expect(result).to eql "short"
        @redis.get("test_key|a2e7e06547b31ddc5dff0eba32b64753|").should eql Marshal.dump("short")
      end
      it "decompresses compressed value" do
        @coffee_table = CoffeeTable::Cache.new(:redis => @redis, :compress_min_size => 20)
        @coffee_table.fetch(:test_key) do
          "this string should be long"
        end
        result = @coffee_table.fetch(:test_key) do
          "this string should be long"
        end
        expect(result.class).to eql String
        expect(result).to eql "this string should be long"

      end
      it "does not decompress a non compressed value" do
        @coffee_table = CoffeeTable::Cache.new(:redis => @redis, :compress_min_size => 20)
        @coffee_table.fetch(:test_key) do
          "short"
        end
        result = @coffee_table.fetch(:test_key) do
          "short"
        end
        expect(result).to eql "short"
      end


    end

    context "keys" do
      it "should create a key with just the initial key" do
        md5 = md5_block do
          "this is a changed value"
        end
        result = @coffee_table.fetch(:test_key) do
          "this is a changed value"
        end
        expect(@coffee_table.keys).to eq ["test_key|#{md5}|"]
      end

      it "should create key from class" do
        md5 = md5_block do
          "this is a changed value"
        end
        result = @coffee_table.fetch(:test_key, SampleClass) do
          "this is a changed value"
        end
        expect(@coffee_table.keys).to eq ["test_key|#{md5}|sample_classes|"]
      end

      it "should use class name for keys" do
        md5 = md5_block do
          "this is a changed value"
        end
        result = @coffee_table.fetch(:test_key, SampleClass.new(2)) do
          "this is a changed value"
        end
        expect(@coffee_table.keys).to eq ["test_key|#{md5}|sample_class[2]|"]
      end

      it "should use id from class in key" do
        md5 = md5_block do
          "this is a changed value"
        end
        result = @coffee_table.fetch(:test_key, SampleClass.new(2)) do
          "this is a changed value"
        end
        expect(@coffee_table.keys).to eq ["test_key|#{md5}|sample_class[2]|"]
      end

    end


    context "with related objects" do
      it "should create a key from the id's of the related objects" do
        test_object = SampleClass.new(9938)
        md5 = md5_block do
          "this is a changed value"
        end
        result = @coffee_table.fetch(:test_key, test_object) do
          "this is a changed value"
        end

        expect(@coffee_table.keys).to include "test_key|#{md5}|sample_class[9938]|"

      end
      it "should raise an exception if a related object does not respond_to id" do
        test_object = SampleClassWithoutId.new

        lambda {
          result = @coffee_table.fetch(:test_key, test_object) do
            "this is a changed value"
          end
        }.should raise_exception CoffeeTable::InvalidObjectError, "Objects passed in must have an id method or be a class"

      end

      it "should create a universal key if the objects passed in are an uninitialised class" do
        md5 = md5_block do
          "this is a changed value"
        end

        result = @coffee_table.fetch(:test_key, SampleClass) do
          "this is a changed value"
        end

        expect(@coffee_table.keys).to include "test_key|#{md5}|sample_classes|"
      end

    end
    context "with expiry" do
      it "keys should update when cache expires" do
        @coffee_table.fetch(:test_key, :expiry => 1) do
          "object1"
        end
        expect(@coffee_table.keys.count).to eq 1
        sleep 1
        expect(@coffee_table.keys.count).to eq 0
      end
      it "should not execute block during cache period" do
        value = 'this is a value'
        @coffee_table.fetch("asdf", :expiry => 1) do
          value
        end
        value = 'this is a changed value'
        result = @coffee_table.fetch("asdf") do
          value
        end
        expect(result).to eq "this is a value"
      end
      it "should execute block and return value when cache has expired" do
        @coffee_table.fetch("asdf", :expiry => 1) do
          "this is a value"
        end
        sleep 2
        result = @coffee_table.fetch("asdf") do
          "this is a changed value"
        end
        expect(result).to eq "this is a changed value"
      end
    end
    context "with force" do
      it "keys should update when cache expires" do
        @coffee_table.fetch(:test_key, :force => true) do
          "object1"
        end
        expect(@coffee_table.keys.count).to eq 1
      end
      it "should not execute block during cache period" do
        value = 'this is a value'
        @coffee_table.fetch("asdf") do
          value
        end
        value = 'this is a changed value'
        result = @coffee_table.fetch("asdf", :force => true) do
          value
        end
        expect(result).to eq "this is a changed value"
      end
    end

    context "changing block" do
      it "should not change key with same code" do
        object = "object1"
        @coffee_table.get_cache(:test_key) do
          object
        end
        object = "object2"
        result = @coffee_table.get_cache(:test_key) do
          object
        end
        expect(result).to eq "object1"
      end
      it "should change key with changed code" do
        @coffee_table.get_cache(:test_key) do
          "object1"
        end
        result = @coffee_table.get_cache(:test_key) do
          "object2"
        end
        expect(result).to eq "object2"
      end
    end
  end

  describe "expire_key" do

    before(:each) do
      @proc_md51 = md5_block do
        "object1"
      end
      @proc_md52 = md5_block do
        "object2"
      end
      @proc_md53 = md5_block do
        "object3"
      end
    end

    it "should expire the specified key" do
      @coffee_table.fetch(:first_key) do
        "object1"
      end
      @coffee_table.fetch(:second_key) do
        "object2"
      end
      @coffee_table.fetch(:third_key) do
        "object3"
      end

      expect(@coffee_table.keys.sort).to eq ["first_key|#{@proc_md51}|", "second_key|#{@proc_md52}|", "third_key|#{@proc_md53}|"].sort
      @coffee_table.expire_key("second_key")
      expect(@coffee_table.keys.sort).to eq ["first_key|#{@proc_md51}|", "third_key|#{@proc_md53}|"].sort

    end
    it "should not expire anything if no matches" do
      @proc_md51 = md5_block do
        "object1"
      end
      @proc_md52 = md5_block do
        "object2"
      end
      @proc_md53 = md5_block do
        "object3"
      end

      @coffee_table.fetch(:first_key) do
        "object1"
      end
      @coffee_table.fetch(:second_key) do
        "object2"
      end
      @coffee_table.fetch(:third_key) do
        "object3"
      end

      expect(@coffee_table.keys.sort).to eq ["first_key|#{@proc_md51}|", "second_key|#{@proc_md52}|", "third_key|#{@proc_md53}|"].sort
      @coffee_table.expire_key("fourth_key")
      expect(@coffee_table.keys.sort).to eq ["first_key|#{@proc_md51}|", "second_key|#{@proc_md52}|", "third_key|#{@proc_md53}|"].sort

    end

  end

  context "monitoring code changes in block" do
    context "changed block" do

      it "should invalidate cache when block has changed" do
        @coffee_table.fetch(:test_key) do
          "object1"
        end

        result = @coffee_table.fetch(:test_key) do
          "object2"
        end

        expect(result).to eq "object2"
      end

      it "should not invalidate block when block has not changed" do
        object = "object1"
        @coffee_table.fetch(:test_key) do
          object
        end

        object = "object2"
        result = @coffee_table.fetch(:test_key) do
          object
        end

        expect(result).to eq "object1"
      end

      it "should not be affected by whitespace only changes" do
        object = "object1"
        @coffee_table.fetch(:test_key) do
          object
        end

        object = "object2"
        result = @coffee_table.fetch(:test_key) do
                  object
        end

        expect(result).to eq "object1"
      end

    end

    context "ignoring code changes" do

      before(:each) do
        @coffee_table = CoffeeTable::Cache.new(:ignore_code_changes => true)
      end

      it "should not invalidate cache when block has changed" do
        @coffee_table.fetch(:test_key) do
          "object1"
        end

        result = @coffee_table.fetch(:test_key) do
          "object2"
        end

        expect(result).to eq "object1"
      end
    end
  end

  describe "expire_all" do
    before(:each) do

      object1 = [SampleClass.new(1), SampleClass.new(2), SampleClass.new(3)]
      object2 = [SampleClass.new(4), SampleClass.new(2), SampleClass.new(5)]
      object3 = [SampleClass.new(7), SampleClass.new(2), SampleClass.new(8)]

      @coffee_table.fetch(:first_key) do
        "object1"
      end
      @coffee_table.fetch(:second_key) do
        "object2"
      end
      @coffee_table.fetch(:third_key) do
        "object3"
      end
    end

    it "should delete all keys" do
      expect(@coffee_table.keys.count).to eq 3
      @coffee_table.expire_all
      expect(@coffee_table.keys.count).to eq 0

      result = @coffee_table.fetch(:first_key) do
        "changed value"
      end

      expect(result).to eq "changed value"

    end
  end

  describe "keys" do
    before(:each) do
      @object1 = [SampleClass.new(1), SampleClass.new(2), SampleClass.new(3)]
      @object2 = [SampleClass.new(4), SampleClass.new(2), SampleClass.new(5)]
      @object3 = [SampleClass.new(7), SampleClass.new(2), SampleClass.new(8)]

      @proc_md51 = md5_block do
        "object1"
      end
      @proc_md52 = md5_block do
        "object2"
      end
      @proc_md53 = md5_block do
        "object3"
      end

    end

    it "should return an array of string" do
      expect(@coffee_table.keys).to be_an_instance_of Array
      @coffee_table.keys.map{|key| expect(key).to be_an_instance_of String}
    end
    it "should return key created without objects" do
      @coffee_table.fetch(:first_key) do
        "object1"
      end
      @coffee_table.fetch(:second_key) do
        "object2"
      end
      @coffee_table.fetch(:third_key) do
        "object3"
      end

      expect(@coffee_table.keys.sort).to eq ["first_key|#{@proc_md51}|",
                               "second_key|#{@proc_md52}|",
                               "third_key|#{@proc_md53}|"].sort

    end
    it "should return key created with objects and ids" do
      @coffee_table.fetch(:first_key, @object1) do
        "object1"
      end
      @coffee_table.fetch(:second_key, @object2) do
        "object2"
      end
      @coffee_table.fetch(:third_key, @object3) do
        "object3"
      end
      expect(@coffee_table.keys.sort).to eq ["first_key|#{@proc_md51}|sample_class[1]|sample_class[2]|sample_class[3]|",
                               "second_key|#{@proc_md52}|sample_class[4]|sample_class[2]|sample_class[5]|",
                               "third_key|#{@proc_md53}|sample_class[7]|sample_class[2]|sample_class[8]|"].sort
    end

  end

  describe "expire_for" do
    before(:each) do
      object1 = [SampleClass.new(1), SampleClass.new(2), SampleClass.new(3)]
      object2 = [SampleClass.new(4), SampleClass.new(2), SampleClass.new(5)]
      object3 = [SampleClass.new(7), SampleClass.new(2), SampleClass.new(8)]

      @coffee_table.fetch(:first_key, object1) do
        "object1"
      end
      @coffee_table.fetch(:second_key, object2) do
        "object2"
      end
      @coffee_table.fetch(:third_key, object3) do
        "object3"
      end
    end

    it "should expire based on the initial key" do
      expect(@coffee_table.keys.count).to eq 3
      @coffee_table.expire_for(:second_key)
      expect(@coffee_table.keys.count).to eq 2
    end

    it "should expire based on a simple string" do
      expect(@coffee_table.keys.count).to eq 3
      @coffee_table.expire_for("sample_class[4]")
      expect(@coffee_table.keys.count).to eq 2
    end

    it "should not expire based on a part match" do
      expect(@coffee_table.keys.count).to eq 3
      @coffee_table.expire_for("impl")
      expect(@coffee_table.keys.count).to eq 3
    end

    it "should not delete any keys if object is not present" do
      expect(@coffee_table.keys.count).to eq 3
      @coffee_table.expire_for(SampleClass.new(18))
      expect(@coffee_table.keys.count).to eq 3
    end
    it "should only delete keys that object is present in" do
      expect(@coffee_table.keys.count).to eq 3
      @coffee_table.expire_for(SampleClass.new(1))
      expect(@coffee_table.keys.count).to eq 2
    end

    it "should delete a key if the object is at the end of they key" do
      expect(@coffee_table.keys.count).to eq 3
      @coffee_table.expire_for(SampleClass.new(3))
      expect(@coffee_table.keys.count).to eq 2
    end

    it "should expire all keys relating to a class if uninitialised class is passed in" do
      @coffee_table.fetch(:fourth_key) do
        "object4"
      end
      expect(@coffee_table.keys.count).to eq 4
      @coffee_table.expire_for(SampleClass)
      expect(@coffee_table.keys.count).to eq 1
    end
  end

end
