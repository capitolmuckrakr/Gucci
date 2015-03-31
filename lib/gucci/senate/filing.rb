require 'nokogiri'
require 'open-uri'
require 'ensure/encoding'

module Gucci
  module Senate
    FILING_TYPES = [:contributiondisclosure,:lobbyingdisclosure1,:lobbyingdisclosure2]

    class Filing

      attr_accessor :download_dir, :html

      attr_reader :filing_id, :filing_url_base, :filing_url,:body, :parsingproblems

      REGISTRATION_URL_BASE = 'http://soprweb.senate.gov/index.cfm?event=getFilingDetails&filingTypeID=1&filingID='

      DISCLOSURE_URL_BASE = 'http://soprweb.senate.gov/index.cfm?event=getFilingDetails&filingTypeID=3&filingID='

      CONTRIBUTION_URL_BASE = 'http://soprweb.senate.gov/index.cfm?event=getFilingDetails&filingTypeID=87&filingID='

      def initialize(filing_id='',opts={})
        @filing_url_base = [REGISTRATION_URL_BASE,DISCLOSURE_URL_BASE,CONTRIBUTION_URL_BASE]
        @filing_id = filing_id
        @opts = opts
        @download_dir = @opts[:download_dir] || Dir.tmpdir
        @opts.delete(:download_dir) if @opts[:download_dir]
      end

      def filing_url
        @filing_url_base[0] + @filing_id
      end

      def filing_type
        if parse.children[1].children[1].children[3].text.scan(/\d+/)[0].to_i > 2
          Gucci::Senate::FILING_TYPES[0]
        else
          Gucci::Senate::FILING_TYPES[parse.children[1].children[1].children[3].text.scan(/\d+/)[0].to_i ]
        end
      end
      def file_path
        File.join(download_dir.to_s, file_name.to_s)
      end

      def file_name
        "#{filing_id}.html"
      end

      def file_download
        File.open(file_path, 'w') do |file|
          open(filing_url,:read_timeout=>3) do |filing|
              begin
                file << filing.read
              rescue
                file << filing.read.ensure_encoding('UTF-8', :external_encoding => Encoding::UTF_8,:invalid_characters => :drop)
              end
          end
        end
        self
      end

      def parse
        begin
          @html ||= Nokogiri::HTML(File.open(file_path,"r"))
        rescue Exception => e
          puts e.message
          puts e.backtrace.inspect
        end
      end

      def check_download
        if file_download.parse.children.children.count == 5
          return true
        else
          @filing_url_base.rotate!
          @html = nil
          return false
        end
      end

      def download
        begin
          until check_download == true
            check_download
          end
          return self.file_path
        rescue => e
          return e.message
        end
      end

      def parse_problem(e,problemfield)
        problem = {}
        problem["field"] = problemfield
        problem["message"] = e.message.to_s
        problem["backtrace"] = e.backtrace.inspect.to_s
        parsingproblems.push(problem) unless e.message.to_s == 'undefined method `children\' for nil:NilClass'
      end
#grab our single fields(organizationName, reportYear, income, expenses, etc), assign keys
      def summary
        registration_keys = [:effectiveDate, :houseID, :senateID, :organizationName, :address1, :address2, :city, :state, :zip, :country, :unknown1, :unknown2, :unknown3, :unknown4,:contactName, :contactPhone, :contactEmail, :registrantGeneralDescription, :clientName, :clientAddress, :clientCity, :clientState, :clientZip, :clientCountry, :unknown5, :unknown6, :unknown7, :unknown8, :clientGeneralDescription,  :printedName, :signedDate]
        disclosure_keys = [:organizationName, :address1, :address2, :city, :state, :zip, :country, :principal_city, :principal_state, :principal_zip, :principal_country, :contactPrefix, :contactName, :contactPhone, :contactEmail, :senateID, :clientName, :houseID, :reportYear, :unknown, :income, :expenses, :printedName, :signedDate]
        keys = [:organizationName, :address1, :address2, :city, :state, :zip, :country, :principal_city, :principal_state, :principal_zip, :principal_country, :contactPrefix, :contactName, :contactPhone, :contactEmail, :senateID, :clientName, :houseID, :reportYear, :unknown, :income, :expenses, :printedName, :signedDate]
        begin
          summary_hash = Gucci::Mapper[*keys.zip(parse.css("div")[1..24].map{|d| d.text.gsub(/[[:space:]]/, ' ').strip}).flatten]
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



    end
  end
end
