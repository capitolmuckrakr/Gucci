require "gucci/version"
require "gucci/filing"
require "gucci/search"

module Gucci
  module House
    class Search
    end
    class Filing
    end
  end
  class Mapper < Hash
    def method_missing(name)
      return self[name] if key? name
      super.method_missing name
    end
    def respond_to_missing?(name, include_private = false)
      key? name || super
    end
  end  
end
