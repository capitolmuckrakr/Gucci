module Filingbody
  def parsefields(n)
    @n = n
    begin
      data = []
      multi(@n).children.each do |m|
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
    #attr_reader name
    define_method("#{name}") do |&block|
      parsed = []
      parsefields(n).each do |row|
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