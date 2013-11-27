module Sphinx
  # Pack ints, floats, strings, and arrays to internal representation
  # needed by Sphinx search engine.
  class Request
    # Initialize new request.
    def initialize
      @request = ''
    end
    
    # Put int(s) to request.
    def put_int(*ints)
      ints.each { |i| request << [i].pack('N') }
    end

    # Put 64-bit int(s) to request.
    def put_int64(*ints)
      ints.each { |i| request << [i].pack('q').reverse }#[i >> 32, i & ((1 << 32) - 1)].pack('NN') }
    end

    # Put string(s) to request (first length, then the string itself).
    def put_string(*strings)
      strings.each { |s| request << [s.bytesize].pack('N') + convert_to_binary(s) }
    end
    
    # Put float(s) to request.
    def put_float(*floats)
      floats.each do |f|
        t1 = [f].pack('f') # machine order
        t2 = t1.unpack('L*').first # int in machine order
        request << [t2].pack('N')
      end
    end
    
    # Put array of ints to request (first length, then the array itself)
    def put_int_array(arr)
      put_int arr.length, *arr
    end

    # Put array of 64-bit ints to request (first length, then the array itself)
    def put_int64_array(arr)
      put_int arr.length
      put_int64(*arr)
    end
    
    # Returns the entire message
    def to_s
      request
    end

  private

    def request
      if @request.respond_to?(:force_encodng)
        @request.force_encoding('ASCII-8BIT')
      else
        @request
      end
    end

    def convert_to_binary(s)
      if s.respond_to?(:force_encoding)
        s.dup.force_encoding('ASCII-8BIT')
      else
        s
      end
    end

  end
end
