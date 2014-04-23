module Gucci
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
