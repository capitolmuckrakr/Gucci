String.class_eval do
  def to_strtime
    begin
      c = self.gsub(/(\/| )/,':').split(':')
      c[3] = c[3].to_i + 12 if c[-1] == "PM" && c.count >3
      c.pop if c.count > 3
      if c.count > 3
        Time.new(c[2],c[0],c[1],c[3],c[4],c[5],"-04:00")
      else
        Time.new(c[2],c[0],c[1],0,0,0,"-04:00") if c.count < 4
      end
    rescue
      self
    end
  end
end

module Gucci
  class Mapper < Hash
    def method_missing(name)
      return self[name] if key? name
      super.method_missing name
    end
    def respond_to_missing?(name, include_private = false)
      key? name || super
    end
    def empty_record?
      self.values.join.empty?
    end
  end
end
