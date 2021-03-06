require 'nokogiri'
require 'open-uri'
require 'ensure/encoding'
require_relative 'filingbody'

module Gucci

  module House

    class Filing

      attr_accessor :download_dir, :xml

      attr_reader :filing_id, :body, :parsingproblems

      def initialize(filing_id,opts={})
        @filing_id = filing_id
        @opts = opts
        @download_dir = @opts[:download_dir] || Dir.tmpdir
      end

      def download
        File.open(file_path, 'w') do |file|
          open(filing_url) do |filing|
            if filing.content_type == "text/xml"
              begin
                file << filing.read
              rescue
                file << filing.read.ensure_encoding('UTF-8', :external_encoding => Encoding::UTF_8,:invalid_characters => :drop)
              end
            else
              begin
                puts "Filetype is #{filing.content_type} and can't be parsed."
                return false
              ensure
                File.delete(file_path)
              end
            end
          end
        end
        self
      end

      def parse
        begin
          @xml ||= Nokogiri::XML(File.open(file_path,"r"))
        rescue Exception => e
          puts e.message
          puts e.backtrace.inspect
        end
      end

      def body
        @body ||= filing_type == FILING_TYPES[0] ? Contribution.new(filing_id,@opts) : nil
        @body ||= filing_type == FILING_TYPES[1] ? Registration.new(filing_id,@opts) : nil
        @body ||= filing_type == FILING_TYPES[2] ? Report.new(filing_id,@opts) : nil
      end

      def parse_problem(e,problemfield)
        problem = {}
        problem["field"] = problemfield
        begin
          problem["message"] = e.message.to_s
          problem["backtrace"] = e.backtrace.inspect.to_s
        rescue
          problem["message"] = e
        end
        if e.respond_to? :message
          parsingproblems.push(problem) unless e.message.to_s == 'undefined method `children\' for nil:NilClass'
        else
          parsingproblems.push(problem)
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

      def multi(n)
        @n = n
        multi ||= multinodes[@n]
      end

      def disclosure_url_base
        'http://disclosures.house.gov/ld/pdfform.aspx?id='
      end

      def contribution_url_base
         'http://disclosures.house.gov/lc/xmlform.aspx?id='
      end

      def filing_url_base
        @filing_id.to_s[0] == '7' ? contribution_url_base : disclosure_url_base
      end

      def filing_url
        filing_url_base + filing_id.to_s
      end

      def filing_type
        parse.root.name.to_s.downcase.to_sym || nil
      end

      def file_path
        File.join(download_dir.to_s, file_name.to_s)
      end

      def file_name
        "#{filing_id}.xml"
      end

      private :parse,:multinodes,:multi,:filing_url_base,:disclosure_url_base,:contribution_url_base,:parse_problem

    end

    class Registration < Filing

      include Filingbody

      attr_reader :lobbyists,:issues,:affiliatedOrgs,:foreignEntities,:parsingproblems

      def initialize(filing_id,opts={})
        @filing_id = filing_id
        @opts = opts
        @parsingproblems = []
        @download_dir = @opts[:download_dir] || Dir.tmpdir
        @issues_parsed = 0
        self.bodymethod("lobbyists",0)
        self.bodymethod("affiliatedOrgs",2)
        self.bodymethod("foreignEntities",3)
      end

      def issues
        @issues ||= []
        if @issues_parsed == 0
          multi(1).children.each do |m|
            if m.name != 'text'
              @issues.push m.text if m.children.count > 0
            end
          end
          @issues_parsed = 1
        end
        @issues.compact
      end

      private :parsefields,:file_path,:download_dir,:download_dir=,:xml,:xml=,:filing_id,:body,:filing_type,:file_name,:download,:summary,:filing_url
      protected :bodymethod

    end

    class Report < Filing

      attr_reader :issues, :updates, :parsingproblems

      def initialize(filing_id,opts={})
        @filing_id = filing_id
        @opts = opts
        @parsingproblems = []
        @download_dir = @opts[:download_dir] || Dir.tmpdir
      end

# we need this to parse agencies for older filings with a slightly different xml tree
      def parse_old_agencies(n)
        agencies_data = n.children.select{|a| a if a.name == "federal_agencies" }[0]
        agencies_result = []
        agencies_data.children.map do |a|
          agencies_result.push('U.S. House of Representatives') if a.name == "house" && a.text =="Y"
          agencies_result.push('U.S. Senate') if a.name == "senate" && a.text =="Y"
          other = a.text if a.name == "other" && a.text != ''
          if other.respond_to? :split #try to separate each agency into an array element
            agencies_result += other.gsub(/(\n|\s{10}|;|.  )/,',').split(',')
          else
            agencies_result.push(other)
          end
        end
        agencies_result.compact!
        return agencies_result
      end
#grab our fields for alis(issues,agencies,lobbyists,etc), remove blank text nodes, assign keys
      def parse_issues
        begin
          data = []
          if multi(0).name == 'alis'
            multi(0).children.each do |m|
              if m.node_name == 'ali_info'
                issuefields = Gucci::Mapper.new
                m.children.map do |i|
                  if i.name != 'lobbyists'
                    issuefields[i.name.to_sym] = nil if i.children.count < 2
                    unless i.content.strip.empty?
                      issuefields[i.name.to_sym] = i.content if i.children.count < 2
                    end
                    issuefields[i.name.to_sym] = i unless i.children.count < 2
                  else
                    issuefields[i.name.to_sym] = i
                  end
                end
                @lobbyists = []
                unless issuefields[:lobbyists].nil?
                  if issuefields[:lobbyists].respond_to? :children
                    issuefields[:lobbyists].children.each do |l|
                      next if l.content == 'N'
                      @lobbyist = Gucci::Mapper.new
                      l.children.each do |f|
                        @lobbyist[f.name.to_sym] = nil
                        @lobbyist[f.name.to_sym] = f.content unless f.content.strip.empty?
                      end
                      @lobbyists.push(@lobbyist) unless @lobbyist.values.join.strip == 'N'
                    end
                  end
                end
                issuefields[:lobbyists] = @lobbyists #need to assign one lobbyist hash for empties
                @agencies = issuefields[:federal_agencies].split(",").each {|agency| agency.strip! if agency.respond_to? :strip! } if issuefields[:federal_agencies].respond_to? :split
                @agencies = parse_old_agencies(m) unless issuefields[:federal_agencies].respond_to? :split
                issuefields[:federal_agencies] = @agencies
                @descriptions = []
                if issuefields[:specific_issues].kind_of? Nokogiri::XML::Element
                  issuefields[:specific_issues].children.each do |si|
                    @descriptions.push(si.content)
                  end
                  issuefields[:specific_issues] = @descriptions
                end
                data.push(issuefields)
              else
                parse_problem(m,"parse_issues") unless m.name == 'text'
              end
            end
          end
          data || nil
        rescue Exception=>e
          parse_problem(e,'@issues')
        end
      end

      def issues(&block)
        parsed = []
        parse_issues.each do |row|
          if block_given?
            yield row
          else
            parsed << row
          end
        end
        block_given? ? nil : parsed
      end

#grab our fields for updates(change of address,inactive lobbyists,inactive issues,etc), remove blank text nodes, assign keys
      def updates
        @updates = Gucci::Mapper.new
        multi(1).children.each do |m|
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
                @inactiveOrgs.push(@inactiveOrg)
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

      private :parse_issues,:download_dir,:download_dir=,:xml,:xml=,:filing_id,:body,:download,:summary,:filing_url,:filing_type,:file_path,:file_name

    end

    class Contribution < Filing

      include Filingbody

      attr_reader :pacs, :contributions, :parsingproblems

      def initialize(filing_id,opts={})
        @filing_id = filing_id
        @opts = opts
        @parsingproblems = []
        @download_dir = @opts[:download_dir] || Dir.tmpdir
        @pacs_parsed = 0
        self.bodymethod("contributions",1)
      end

      def pacs
        @pacs ||= []
        if @pacs_parsed == 0
          multi(0).children.each do |m|
            if m.name != 'text'
              @pacs.push m.children.children.text.strip if m.children.children.count > 0
            end
          end
          @pacs_parsed = 1
        end
        @pacs
      end

      private :parsefields,:file_path,:download_dir,:download_dir=,:xml,:xml=,:filing_id,:body,:filing_type,:file_name,:download,:summary,:filing_url
      protected :bodymethod

    end

  end

end
