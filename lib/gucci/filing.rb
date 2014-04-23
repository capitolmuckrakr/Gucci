require 'nokogiri'
require 'open-uri'
require 'ensure/encoding'

module Gucci
  module House
    class Filing

      attr_accessor :xml, :download_dir

      attr_reader :filing_id, :summary,  :issues, :updates, :parsingproblems

      def initialize(filing_id,opts={})
        @filing_id = filing_id
        @download_dir = opts[:download_dir]
        @parsingproblems = []
        @summary = {}
        @issues = []
        @updates = {}
      end

      def download
        File.open(file_path, 'w') do |file|
          begin
            file << open(filing_url).read
          rescue
            file << open(filing_url).read.ensure_encoding('UTF-8', :external_encoding => Encoding::UTF_8,:invalid_characters => :drop)
          end
        end
        self
      end

      def parse
        begin
          @xml ||= Nokogiri::XML(File.open(file_path,"r"))
          #return @xml
        rescue Exception => e
          puts e.message
          puts e.backtrace.inspect
        end
      end

#grab our single fields(organizationName, reportYear, income, expenses, etc), remove carriage returns, assign keys
     def summary
       summary_hash ||= Gucci::Mapper.new
       begin
         parse.children.each do |node| #only one child we need
           if node.element? #should pass unless filing is malformed
             node.children.each do |childnode| # access top-level fields
               if childnode.children.count < 2 && childnode.node_name != 'text' #test for single-value fields such as registrantname, clientname, etc. Skip linefeeds.
                 begin
                   summary_hash[childnode.name.to_sym] ||= nil
                   unless childnode.content.strip.empty?
                     begin
                       summary_hash[childnode.name.to_sym] = childnode.content #transform into hash
                     rescue Exception=>e
                       parse_problem(e,'@summary.' + childnode.name.to_s)
                     end
                   end
                 rescue Exception=>e
                   parse_problem(e,childnode)
                 end
               end
             end
           end
         end
       rescue Exception=>e
         parse_problem(e,'@summary')
       end
       data ||= summary_hash
     end

#grab our fields for alis(issues,agencies,lobbyists,etc), remove blank text nodes, assign keys
     def issues
       begin
         multi ||= multinodes[0].dup
         multi.children.each do |m|
           if m.node_name != 'text'
             issuefields = Gucci::Mapper.new
             m.children.map{ |i| issuefields[i.name.to_sym] = nil if i.children.count < 2 }
             m.children.map do |i|
               unless i.content.strip.empty?
                 issuefields[i.name.to_sym] = i.content if i.children.count < 2
               end
             end
             m.children.map{ |i| issuefields[i.name.to_sym] = i unless i.children.count < 2 }
             @lobbyists = []
             issuefields[:lobbyists].children.each do |l|
               next if l.content == 'N'
               @lobbyist = Gucci::Mapper.new
               l.children.each do |f|
                 @lobbyist[f.name.to_sym] = nil
                 @lobbyist[f.name.to_sym] = f.content unless f.content.strip.empty?
               end
               @lobbyists.push(@lobbyist) unless @lobbyist.values.join.strip == 'N'
             end
             issuefields[:lobbyists] = @lobbyists #need to assign one lobbyist hash for empties
             @agencies = issuefields[:federal_agencies].split(",").each {|agency| agency.strip! if agency.respond_to? :strip! } if issuefields[:federal_agencies].respond_to? :split
             issuefields[:federal_agencies] = @agencies
             @descriptions = []
             if issuefields[:specific_issues].kind_of? Nokogiri::XML::Element
               issuefields[:specific_issues].children.each do |si|
                 @descriptions.push(si.content)
               end
               issuefields[:specific_issues] = @descriptions
             end
             @issues.push(issuefields)
           end
         end
         @issues
       rescue Exception=>e
         parse_problem(e,'@issues')
       end
     end
#grab our fields for updates(change of address,inactive lobbyists,inactive issues,etc), remove blank text nodes, assign keys
     def updates
       @updates = Gucci::Mapper.new
       multi = multinodes[1].dup
       multi.children.each do |m|
         if m.node_name != 'text'
           if m.children.count < 2
               @updates[m.name.to_sym] = nil
               @updates[m.name.to_sym] = m.content unless m.content.strip.empty? || m.children.children.count > 1
           end
           @updates[m.name.to_sym] = m if m.children.count > 1 || m.children.count < 2 && m.children.children.count > 1
           @inactive_lobbyists = []
           begin
             @updates[:inactive_lobbyists].children.each do |l|
                 next if l.content.empty?
               @inactive_lobbyist = Gucci::Mapper.new
               l.children.each do |f|
                 @inactive_lobbyist[f.name.to_sym] = f.content
               end
               @inactive_lobbyists.push(@inactive_lobbyist)
             end
             @updates[:inactive_lobbyists] = @inactive_lobbyists
           rescue Exception=>e
             parse_problem(e,'@updates[:inactive_lobbyists]')
           end
           @inactive_alis = []
           begin
             @updates[:inactive_ALIs].children.each do |ia|
               next if ia.content.empty?
               @inactive_ali = ia.content
               @inactive_alis.push(@inactive_ali)
             end
             @updates[:inactive_ALIs] = @inactive_alis
           rescue Exception=>e
             parse_problem(e,'@updates[:inactive_ALIs]')
           end
           @inactiveOrgs = []
           begin
             @updates[:inactiveOrgs].children.each do |ia|
               next if ia.content.empty?
               @inactiveOrg = ia.content
               @inactiveOrgs.push(@inactive_ali)
             end
             @updates[:inactiveOrgs] = @inactiveOrgs
           rescue Exception=>e
             parse_problem(e,'@updates[:inactiveOrgs]')
           end
           @inactive_ForeignEntities = []
           begin
             @updates[:inactive_ForeignEntities].children.each do |ia|
               next if ia.content.empty?
               @inactive_ForeignEntity = ia.content
               @inactive_ForeignEntities.push(@inactive_ForeignEntity)
             end
             @updates[:inactive_ForeignEntities] = @inactive_ForeignEntities
           rescue Exception=>e
             parse_problem(e,'@updates[:inactive_ForeignEntities]')
           end
           @affiliatedOrgs = []
           begin
             @updates[:affiliatedOrgs].children.each do |a|
               next if a.content.empty?
               @affiliatedOrg = Gucci::Mapper.new
               a.children.each do |f|
                 @affiliatedOrg[f.name.to_sym] = f.content
               end
               @affiliatedOrgs.push(@affiliatedOrg)
             end
             @updates[:affiliatedOrgs] = @affiliatedOrgs
           rescue Exception=>e
             parse_problem(e,'@updates[:affiliatedOrgs]')
           end
           @foreignEntities = []
           begin
             @updates[:foreignEntities].children.each do |a|
               next if a.content.empty?
               @foreignEntity = Gucci::Mapper.new
               a.children.each do |f|
                 @foreignEntity[f.name.to_sym] = f.content
               end
               @foreignEntities.push(@foreignEntity)
             end
             @updates[:foreignEntities] = @foreignEntities
           rescue Exception=>e
             parse_problem(e,'@updates[:foreignEntities]')
           end
         end
       end
       @updates
     end

     def parse_problem(e,problemfield)
       problem = {}
       problem["field"] = problemfield
       problem["message"] = e.message.to_s
       problem["backtrace"] = e.backtrace.inspect.to_s
       parsingproblems.push(problem) unless e.message.to_s == 'undefined method `children\' for nil:NilClass'
     end

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

     def filing_url_base
       'http://disclosures.house.gov/ld/pdfform.aspx?id='
     end

     def filing_url
       filing_url_base + filing_id
     end

     def file_path
       File.join(download_dir.to_s, file_name.to_s)
     end

     def file_name
        "#{filing_id}.xml"
     end

    end
  end
end
