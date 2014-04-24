module FilingUtils
  def multinodes
    multinodelist = []
    parse.children.each do |node| #only one child
      if node.element? #should pass unless filing is malformed or xslt
        node.children.each do |childnode| # access top-level fields
          if childnode.children.count > 1 && childnode.node_name != 'text' #skip single-value top level fields such as registrantname, clientname, etc. Skip linefeeds.
            childnode.children.each do |m|
              m.children.map{ |i| i.remove if i.name == 'text' && i.blank? }
              m.children.map{ |i| i.children.map{ |i2| i2.remove if i2.name == 'text' && i2.blank? } }
              m.children.map{ |i| i.children.map{ |i2| i2.children.map{ |i3| i3.remove if i3.name == 'text' && i3.blank? } } }
            end
            multinodelist.push(childnode)
          end
        end
      end
    end
    multinodelist
  end
end
