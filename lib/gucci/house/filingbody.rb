module Filingbody
  def parsefields(n)
    @n = n
    begin
      data = []
      multi(@n).children.each do |m| # if we decouple this block from multi call, we can use it more widely on any field that's an array of hashes
        if m.name != 'text'
          parsedfields = Gucci::Mapper.new
          m.children.map do |m1|
            parsedfields[m1.name.to_sym] = nil
            unless m1.content.strip.empty?
              parsedfields[m1.name.to_sym] = m1.content
            end
          end
          data.push(parsedfields)
        end
      end
      data || nil
    rescue Exception=>e
      parse_problem(e,'parsedfields')
    end
  end

  def bodymethod(name,n)
    define_singleton_method("#{name}") do |&block|
      parsed = []
      parsefields(n).each do |row| # if we decouple the rest of this block, we can use it much more widely to return our arrays of hashes
        if block_given?
          yield row
        else
          parsed << row
        end
      end
      block_given? ? nil : parsed
    end
  end
end