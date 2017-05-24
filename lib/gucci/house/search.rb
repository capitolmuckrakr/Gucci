require 'watir'
require 'fileutils'
require 'date'

module Gucci
  module House
    # Gucci::House::Search is an interface for the Clerk of the House's lobbying filing search forms
    # (http://disclosures.house.gov/ld/ldsearch.aspx & http://disclosures.house.gov/lc/lcsearch.aspx)
    class Search

    # @param [Hash] opts a hash of parameters to be
    # passed to the search form.
      attr_accessor :download_dir, :search_params, :status, :pages, :filings
      
      def initialize(opts={})
        @search_type = opts[:contributions]? opts[:contributions]=="contributions"? :contributions : :contribution_filings : :disclosure_filings
        opts.delete(:contributions) if opts[:contributions]
        @verbose = opts[:verbose] ? true : false
        opts.delete(:verbose) if opts[:verbose]
        @browser = browser
        @search_params = validate_params(make_params(opts))
        search(@search_params)
        @browser.close
      end

      def browser
        browser = Watir::Browser.new :phantomjs
        url = ''
        if @search_type =~ /contribution/
          url = 'disclosures.house.gov/lc/lcsearch.aspx'
        else
           url = 'disclosures.house.gov/ld/ldsearch.aspx'
        end
        browser.goto url
        return browser
      end

      def search(params)
        param_count = 0
        selected_params = {}
        if @search_type == :contributions
          @browser.radio(:id=>'radioFilingType_0').set
          @browser.button(:name => 'cmdSearch').click
        end
        params.each_key do |param|
          param_count += 1
          selected_params[param_count] = param
          param_id = "DropDownList#{param_count}"
          @browser.select_list(:id => "#{param_id}").select "#{param}"
          sleep 1
        end
        @browser.button(:name => 'cmdSearch').click
        begin
          selected_params.keys.sort.each do |param_order|
            param_id = valid_params.keys.include?(selected_params[param_order]) ? "DropDownList#{param_order}0" : "TextBox#{param_order}"
            if valid_params.keys.include?(selected_params[param_order])
              @browser.select_list(:id => "#{param_id}").select "#{params[selected_params[param_order]]}"
            else
              @browser.text_field(:id => "#{param_id}").set "#{params[selected_params[param_order]]}"
            end
            sleep 1
          end
          @browser.button(:name => 'cmdSearch').click
        rescue
        end
        raise ArgumentError, "There was an error with the Lobby Search System. Try your search again or contact the Legislative Resource Center." if @browser.text.scan(/There was an error with the Lobby/)[0] == "There was an error with the Lobby"
        begin
          @status = @browser.body.text.scan(/\d+ of \d+ Total \d+/)[0]
          @pages = @status.scan(/of (.*?) Total/).flatten[0].gsub(',','').to_i
          @pages +=1 if @pages > 1 #do we need to do this?
          @filings = parse_results
          return @browser
        rescue
          return @browser
        end
      end

      def parse_results()
        filings = []
        while @pages >0
          puts "Processing page #{@pages}" if @verbose
          rownum = 0
          @browser.trs(:class=>/(defaultRow|altRow)/).each do |row|
            rownum+=1 if @verbose
            puts "Processing row #{rownum} from page #{@pages}" if @verbose
            newrow = []
            row.tds.each{ |t| newrow.push(t.text) }
            filing_id = ''
            filing_id+=row.html
            newrow.unshift(filing_id.scan(/id\=(\d+)/)[0])
            newrow = newrow.flatten
            filings.push(newrow)
            newrow = nil
            filing_id = nil
          end
          @pages-=1
          @browser.button(:name=>"btnNext2").click if @pages > 0
        end
        filings.sort_by!{|e| e[0].to_i}.reverse! #largest filing_id is newest
        return filings
      end

      def results(&block)
        #rewrite keys based on param selection?
        disclosure_keys = [:filing_id, :house_id, :registrant_name, :client_name, :filing_year, :filing_period, :lobbyists, :remaining_items]
        contribution_keys = [:filing_id,:house_id,:organization_name,:lobbyist_name,:payee_name,:recipient_name,:contributor_name,:amount ]
        contribution_filing_keys = [:filing_id,:house_id,:organization_name,:remaining_items ]
        keys = []
        if @search_type == :contributions
          keys = contribution_keys
        elsif @search_type ==  :contribution_filings
          keys = contribution_filing_keys
        else
          keys = disclosure_keys
        end
        parsed_results = []
        @filings.each do |row|
          next if row.empty?
          row = [row[0..2],row[3..-1].join(",")].flatten if @search_type == :contribution_filings
          row = [row[0..6],row[7..-1].join(",")].flatten unless @search_type.to_s =~ /contribution/
          search_result ||= Gucci::Mapper[*keys.zip(row).flatten]
          search_result[:lobbyists] = search_result.lobbyists.split("\n").uniq.sort.map{|l| l.strip} if search_result.keys.include?(:lobbyists)
          search_result[:amount] = search_result.amount.strip if search_result.keys.include?(:amount)
          if block_given?
            yield search_result
          else
            parsed_results << search_result
          end
        end
        block_given? ? nil : parsed_results
      end

      def make_params(search_params)
        if @search_type == :contributions
          make_contribution_params(search_params)
        elsif @search_type == :contribution_filings
          make_contribution_filing_params(search_params)
        else
          make_disclosure_params(search_params)
        end
      end

      def make_disclosure_params(search_params)
        {
        'Registrant Name' => search_params[:registrant_name] || '', #validate?
        'Client Name' => search_params[:client_name] || '', #validate?
        'House ID' => search_params[:registrant_id] || '', #validate?
        'Filing Period' => search_params[:filing_period] || '',
        'Filing Type' => search_params[:filing_type] || '',
        'Filing Year' => search_params[:filing_year] || '',
        'Issue Code' => search_params[:issue_code] || '',
        'Lobbyist Name' => search_params[:lobbyist_name] || '', #validate?
        'Affiliated Country' => search_params[:affiliated_country] || '',
        'Affiliated Name' => search_params[:affiliated_name] || '', #validate?
        'Amount Reported' => search_params[:amount_reported] || '', #validate?
        'Client Country' => search_params[:client_country] || '',
        'Client PPB Country' => search_params[:client_ppb_country] || '',
        'Client State' => search_params[:client_state] || '',
        'Foreign Entiry PPB Country' => search_params[:foreign_entity_ppb_country] || '', #typo in field name on House form
        'Foreign Entity Country' => search_params[:foreign_entity_country] || '',
        'Foreign Entity Name' => search_params[:foreign_entity_name] || '', #validate?
        'Foreign Entity Ownership' => search_params[:foreign_entity_ownership] || '', #validate?
        'Government Entity' => search_params[:government_entity] || '', #validate?
        'Issue Data' => search_params[:issue_data] || '', #validate?
        'Lobbyist Covered' => search_params[:lobbyist_covered] || '',
        'Lobbyist Covered Position' => search_params[:lobbyist_position] || '', #validate?
        'Lobbyists Full Name Inactive' => search_params[:lobbyist_inactive] || '', #validate?
        'Registrant Country' => search_params[:registrant_country] || '',
        'Registrant PPB Country' => search_params[:registrant_ppb_country] || ''
        }
      end

      def make_contribution_filing_params(search_params)
        {
        'Organization Name' => search_params[:organization_name] || '',
        'House ID' => search_params[:registrant_id] || '',
        'Filing Period' => search_params[:filing_period] || '',
        'Filing Type' => search_params[:filing_type] || '',
        'PAC' => search_params[:pac] || '',
        'Filing Year' => search_params[:filing_year] || '',
        'Lobbyist Name' => search_params[:lobbyist_name] || '',
        'Contact Name' => search_params[:contact_name] || '',
        'Senate ID' => search_params[:senate_id] || ''
        }
      end

      def make_contribution_params(search_params)
        {
        'Organization Name' => search_params[:organization_name] || '',
        'House ID' => search_params[:registrant_id] || '',
        'Filing Period' => search_params[:filing_period] || '',
        'Contribution Type' => search_params[:contribution_type] || '',
        'Lobbyist Name' => search_params[:lobbyist_name] || '',
        'Honoree' => search_params[:honoree] || '',
        'Payee Name' => search_params[:payee_name] || '',
        'Contributor Name' => search_params[:contributor_name] || '',
        'Amount' => search_params[:contributor_name] || '',
        'Senate ID' => search_params[:senate_id] || ''
        }
      end

      def valid_params
        if @search_type == :contributions
          VALID_CONTRIBUTION_PARAMS
        elsif @search_type == :contribution_filings
          VALID_CONTRIBUTION_FILING_PARAMS
        else
          VALID_DISCLOSURE_PARAMS
        end
      end

      def validate_params(params)
        raise ArgumentError, "At least one search parameter must be given, possible parameters are #{valid_params.keys.join(', ')}" if params.values.all? { |x| x.to_s.empty? }
        params.delete_if { |k,v| v.to_s.empty? }
        raise ArgumentError, "No more than six search parameters are permitted" if params.keys.count > 6
        invalid_params = []
        valid_params.each_pair do |k,v|
          if params.keys.include?(k)
            invalid_params.push("#{params[k]} is invalid for #{k}, permitted values are #{v.join(', ')}\n") unless valid_params[k].include?( params[k] )
          end
        end
        raise ArgumentError, "#{invalid_params.count} error(s)\n#{invalid_params.join.chomp}" unless invalid_params.empty?
        params
      end

    end

      COUNTRIES = {
      "AFG" => "AFGHANISTAN",
  		"ALB" => "ALBANIA",
  		"ALG" => "ALGERIA",
  		"ASA" => "AMERICAN SAMOA",
  		"AND" => "ANDORRA",
  		"ANG" => "ANGOLA",
  		"ANT" => "ANTIGUA/BARBUDA",
  		"ARG" => "ARGENTINA",
  		"ARM" => "ARMENIA",
  		"ARU" => "ARUBA",
  		"AUS" => "AUSTRALIA",
  		"AUT" => "AUSTRIA",
  		"AZE" => "AZERBAIJAN",
  		"BAH" => "BAHAMAS",
  		"BRN" => "BAHRAIN",
  		"BAN" => "BANGLADESH",
  		"BAR" => "BARBADOS",
  		"BLR" => "BELARUS",
  		"BEL" => "BELGIUM",
  		"BIZ" => "BELIZE",
  		"BEN" => "BENIN",
  		"BER" => "BERMUDA",
  		"BHU" => "BHUTAN",
  		"BOL" => "BOLIVIA",
  		"BIH" => "BOSNIA/HERZEGOVINA",
  		"BOT" => "BOTSWANA",
  		"BRA" => "BRAZIL",
  		"IVB" => "BRITISH VIRGIN ISLANDS",
  		"BRU" => "BRUNEI",
  		"BUL" => "BULGARIA",
  		"BUR" => "BURKINA FASO",
  		"BDI" => "BURUNDI",
		"CAM" => "CAMBODIA",
		"CMR" => "CAMEROON",
		"CAN" => "CANADA",
		"CPV" => "CAPE VERDE",
		"CAY" => "CAYMAN ISLANDS",
		"CAF" => "CENTRAL AFRICAN REPUBLIC",
		"CHA" => "CHAD",
		"CHI" => "CHILE",
		"CHN" => "CHINA",
		"COL" => "COLOMBIA",
		"COM" => "COMOROS",
		"COD" => "CONGO, DEMOCRATIC REPBLIC OF THE",
		"CGO" => "CONGO, REPUBLIC OF THE",
		"COK" => "COOK ISLANDS",
		"CRC" => "COSTA RICA",
		"CIV" => "COTE D'IVOIRE",
		"CRO" => "CROATIA (HRVATSKA)",
		"CUB" => "CUBA",
		"CYP" => "CYPRUS",
		"CZE" => "CZECH REPUBLIC",
		"DEN" => "DENMARK",
		"DJI" => "DJIBOUTI",
		"DMA" => "DOMINICA",
		"DOM" => "DOMINICAN REPUBLIC",
		"ECU" => "ECUADOR",
		"EGY" => "EGYPT",
		"ESA" => "EL SALVADOR",
		"GEQ" => "EQUATORIAL GUINEA",
		"ERI" => "ERITREA",
		"EST" => "ESTONIA",
		"ETH" => "ETHIOPIA",
		"FIJ" => "FIJI",
		"FIN" => "FINLAND",
		"FRA" => "FRANCE",
		"GAB" => "GABON",
		"GAM" => "GAMBIA",
		"GEO" => "GEORGIA",
		"GER" => "GERMANY",
		"GHA" => "GHANA",
		"GRE" => "GREECE",
		"GRN" => "GRENADA",
		"GUM" => "GUAM",
		"GUA" => "GUATEMALA",
		"GUI" => "GUINEA",
		"GBS" => "GUINEA-BISSAU",
		"GUY" => "GUYANA",
		"HAI" => "HAITI",
		"HON" => "HONDURAS",
		"HKG" => "HONG KONG",
		"HUN" => "HUNGARY",
		"ISL" => "ICELAND",
		"IND" => "INDIA",
		"INA" => "INDONESIA",
		"IRI" => "IRAN",
		"IRQ" => "IRAQ",
		"IRL" => "IRELAND",
		"ISR" => "ISRAEL",
		"ITA" => "ITALY",
		"JAM" => "JAMAICA",
		"JPN" => "JAPAN",
		"JOR" => "JORDAN",
		"KAZ" => "KAZAKHSTAN",
		"KEN" => "KENYA",
		"PRK" => "KOREA, REPUBLIC OF",
		"KOR" => "KOREA, REPUBLIC OF",
		"KUW" => "KUWAIT",
		"KGZ" => "KYRGYSTAN",
		"LAO" => "LAOS, PEOPLES DEMOCRACTIC REPUBLIC",
		"LAT" => "LATVIA",
		"LIB" => "LEBANON",
		"LES" => "LESOTHO",
		"LBR" => "LIBERIA",
		"LBA" => "LIBYAN ARAB JAMAHIRIYA",
		"LIE" => "LIECHTENSTEIN",
		"LTU" => "LITHUANIA",
		"LUX" => "LUXEMBORG",
		"MKD" => "MACEDONIA",
		"MAD" => "MADAGASCAR",
		"MAW" => "MALAWI",
		"MAS" => "MALAYSIA",
		"MDV" => "MALDIVES",
		"MLI" => "MALI",
		"MLT" => "MALTA",
		"MTN" => "MAURITANIA",
		"MRI" => "MAURITIUS",
		"MEX" => "MEXICO",
		"FSM" => "MICRONESIA, FEDERATED STATES OF",
		"MDA" => "MOLDOVA, REPUBLIC OF",
		"MON" => "MONACO",
		"MGL" => "MONGOLIA",
		"MAR" => "MOROCCO",
		"MOZ" => "MOZAMBIQUE",
		"MYA" => "MYANMAR",
		"NAM" => "NAMIBIA",
		"NRU" => "NAURU",
		"NEP" => "NEPAL",
		"NED" => "NETHERLANDS",
		"AHO" => "NETHERLANDS ANTILLES",
		"NZL" => "NEW ZEALAND",
		"NCA" => "NICARAGUA",
		"NIG" => "NIGER",
		"NGR" => "NIGERIA",
		"NOR" => "NORWAY",
		"OMA" => "OMAN",
		"PAK" => "PAKISTAN",
		"PLW" => "PALAU",
		"PLE" => "PALESTINE",
		"PAN" => "PANAMA",
		"PNG" => "PAPUA NEW GUINEA",
		"PAR" => "PARAGUAY",
		"PER" => "PERU",
		"PHI" => "PHILIPPINES",
		"POL" => "POLAND",
		"POR" => "PORTUGAL",
		"PUR" => "PUERTO RICO",
		"QAT" => "QATAR",
		"ROM" => "ROMANIA",
		"RUS" => "RUSSIAN FEDERATION",
		"RWA" => "RWANDA",
		"SKN" => "SAINT KITTS &amp; NEVIS",
		"LCA" => "SAINT LUCIA",
		"VIN" => "SAINT VINCENT &amp; GRENADINES",
		"SAM" => "SAMOA",
		"SMR" => "SAN MARINO",
		"STP" => "SAO TOME &amp; PRINCIPE",
		"KSA" => "SAUDI ARABIA",
		"SEN" => "SENEGAL",
		"SEY" => "SEYCHELLES",
		"SLE" => "SIERRA LEONE",
		"SIN" => "SINGAPORE",
		"SVK" => "SLOVAKIA (SLOVAK REPUBLIC)",
		"SLO" => "SLOVENIA",
		"SOL" => "SOLOMON ISLANDS",
		"SOM" => "SOMALIA",
		"RSA" => "SOUTH AFRICA",
		"ESP" => "SPAIN",
		"SRI" => "SRI LANKA",
		"SUD" => "SUDAN",
		"SUR" => "SURINAME",
		"SWZ" => "SWAZILAND",
		"SWE" => "SWEDEN",
		"SUI" => "SWITZERLAND",
		"SYR" => "SYRIAN ARAB REPUBLIC",
		"TRE" => "TAIWAN",
		"TJK" => "TAJIKISTAN",
		"TAN" => "TANZANIA, UNITED REPUBLIC OF",
		"THA" => "THAILAND",
		"TOG" => "TOGO",
		"TGA" => "TONGA",
		"TRI" => "TRINIDAD &amp; TOBAGO",
		"TUN" => "TUNISIA",
		"TUR" => "TURKEY",
		"TKM" => "TURKMENISTAN",
		"UGA" => "UGANDA",
		"UKR" => "UKRAINE",
		"UAE" => "UNITED ARAB EMIRATES",
		"GBR" => "UNITED KINGDOM",
		"URU" => "URUGUAY",
		"USA" => "USA",
		"UZB" => "UZBEKISTAN",
		"VAN" => "VANUATU",
		"VEN" => "VENEZUELA",
		"VIE" => "VIETNAM",
		"ISV" => "VIRGIN ISLANDS",
		"YEM" => "YEMEN",
		"YUG" => "YUGOSLAVIA",
		"ZAM" => "ZAMBIA",
		"ZIM" => "ZIMBABWE"
      }

      REPORT_TYPES = {
        "MM" => "Mid-Year Report",
        "MA" => "Mid-Year Amendment Report",
        "MT" => "Mid-Year Termination Report",
        "M@" => "Mid-Year Termination Amendment Report",
        "YY" => "Year-End Report",
        "YA" => "Year-End Amendment Report",
        "YT" => "Year-End Termination Report",
        "Y@" => "Year-End Termination Amendment Report",
        "RR" => "Registration",
        "RA" => "Registration Amendment",
        "Q1" => "1st Quarter Report",
        "1A" => "1st Quarter Amendment Report",
        "1T" => "1st Quarter Termination Report",
        "1@" => "1st Quarter Termination Amendment Report",
        "Q2" => "2nd Quarter Report",
        "2A" => "2nd Quarter Amendment Report",
        "2T" => "2nd Quarter Termination Report",
        "2@" => "2nd Quarter Termination Amendment Report",
        "Q3" => "3rd Quarter Report",
        "3A" => "3rd Quarter Amendment Report",
        "3T" => "3rd Quarter Termination Report",
        "3@" => "3rd Quarter Termination Amendment Report",
        "Q4" => "4th Quarter Report",
        "4A" => "4th Quarter Amendment Report",
        "4T" => "4th Quarter Termination Report",
        "4@" => "4th Quarter Termination Amendment Report",
        "NR" => "New Registrant Using Web Form"
      }

      ISSUES = {
        "ACC" => "ACCOUNTING",
  			"ADV" => "ADVERTISING",
  			"AER" => "AEROSPACE",
  			"AGR" => "AGRICULTURE",
  			"ALC" => "ALCOHOL AND DRUG ABUSE",
  			"ANI" => "ANIMALS",
  			"APP" => "APPAREL/CLOTHING INDUSTRY/TEXTILES",
  			"ART" => "ARTS/ENTERTAINMENT",
  			"AUT" => "AUTOMOTIVE INDUSTRY",
  			"AVI" => "AVIATION/AIRCRAFT/AIRLINES",
  			"BAN" => "BANKING",
			"BNK" => "BANKRUPTCY",
			"BEV" => "BEVERAGE INDUSTRY",
			"BUD" => "BUDGET/APPROPRIATIONS",
			"CHM" => "CHEMICALS/CHEMICAL INDUSTRY",
			"CIV" => "CIVIL RIGHTS/CIVIL LIBERTIES",
			"CAW" => "CLEAN AIR AND WATER (QUALITY)",
			"CDT" => "COMMODITIES (BIG TICKET)",
			"COM" => "COMMUNICATIONS/BROADCASTING/RADIO/TV",
			"CPI" => "COMPUTER INDUSTRY",
			"CON" => "CONSTITUTION",
			"CSP" => "CONSUMER ISSUES/SAFETY/PRODUCTS",
			"CPT" => "COPYRIGHT/PATENT/TRADEMARK",
			"DEF" => "DEFENSE",
			"DIS" => "DISASTER PLANNING/EMERGENCIES",
			"DOC" => "DISTRICT OF COLUMBIA",
			"ECN" => "ECONOMICS/ECONOMIC DEVELOPMENT",
			"EDU" => "EDUCATION",
			"ENG" => "ENERGY/NUCLEAR",
			"ENV" => "ENVIRONMENT/SUPERFUND",
			"FAM" => "FAMILY ISSUES/ABORTION/ADOPTION",
			"FIN" => "FINANCIAL INSTITUTIONS/INVESTMENTS/SEC",
			"FIR" => "FIREARMS/GUNS/AMMUNITION",
			"FOO" => "FOOD INDUSTRY (SAFETY, LABELING, ETC.)",
			"FOR" => "FOREIGN RELATIONS",
			"FUE" => "FUEL/GAS/OIL",
			"GAM" => "GAMING/GAMBLING/CASINO",
			"GOV" => "GOVERNMENT ISSUES",
			"HCR" => "HEALTH ISSUES",
			"HOM" => "HOMELAND SECURITY",
			"HOU" => "HOUSING",
			"IMM" => "IMMIGRATION",
			"IND" => "INDIAN/NATIVE/AMERICAN AFFAIRS",
			"INS" => "INSURANCE",
			"INT" => "INTELLIGENCE AND SURVEILLANCE",
			"LBR" => "LABOR ISSUES/ANTITRUST/WORKPLACE",
			"LAW" => "LAW ENFORCEMENT/CRIME/CRIMINAL JUSTICE",
			"MAN" => "MANUFACTURING",
			"MAR" => "MARINE/MARITIME/BOATING/FISHERIES",
			"MIA" => "MEDIA (INFORMATION/PUBLISHING)",
			"MED" => "MEDICAL/DISEASE RESEARCH/CLINICAL LABS",
			"MMM" => "MEDICARE/MEDICAID",
			"MON" => "MINTING/MONEY/GOLD STANDARD",
			"NAT" => "NATURAL RESOURCES",
			"PHA" => "PHARMACY",
			"POS" => "POSTAL",
			"RRR" => "RAILROADS",
			"RES" => "REAL ESTATE/LAND USE/CONSERVATION",
			"REL" => "RELIGION",
			"RET" => "RETIREMENT",
			"ROD" => "ROADS/HIGHWAY",
			"SCI" => "SCIENCE/TECHNOLOGY",
			"SMB" => "SMALL BUSINESS",
			"SPO" => "SPORTS/ATHLETICS",
			"TAR" => "TARIFF (MISCELLANEOUS TARIFF BILLS)",
			"TAX" => "TAXATION/INTERNAL REVENUE CODE",
			"TEC" => "TELECOMMUNICATIONS",
			"TOB" => "TOBACCO",
			"TOR" => "TORTS",
			"TRD" => "TRADE (DOMESTIC/FOREIGN)",
			"TRA" => "TRANSPORTATION",
			"TOU" => "TRAVEL/TOURISM",
			"TRU" => "TRUCKING/SHIPPING",
			"UNM" => "UNEMPLOYMENT",
			"URB" => "URBAN DEVELOPMENT/MUNICIPALITIES",
			"UTI" => "UTILITIES",
			"VET" => "VETERANS",
			"WAS" => "WASTE (HAZARD/SOLID/INTERSTATE/NUCLEAR)",
			"WEL" => "WELFARE"
      }

      STATES = ["AL", "AK", "AS", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "GU", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "PR", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VI", "VA", "WA", "WV", "WI", "WY"]
      VALID_DISCLOSURE_PARAMS = {
        'Filing Period' => ["Mid-Year", "Year-End", "1st Quarter", "2nd Quarter", "3rd Quarter", "4th Quarter"],
        'Filing Type' => REPORT_TYPES.values,
        'Filing Year' => (2011..Date.today.year).map{ |y| y },
        'Issue Code' => ISSUES.values,
        'Affiliated Country' => COUNTRIES.values,
        'Client Country' => COUNTRIES.values,
        'Client PPB Country' => COUNTRIES.values,
        'Client State' => STATES,
        'Foreign Entiry PPB Country' => COUNTRIES.values, #typo in field name on House form
        'Foreign Entity Country' => COUNTRIES.values,
        'Lobbyist Covered' => ["True","False"],
        'Registrant Country' => COUNTRIES.values,
        'Registrant PPB Country' => COUNTRIES.values
      }

      VALID_CONTRIBUTION_FILING_PARAMS = {
        'Filing Period' => ["Mid-Year", "Year-End"],
        'Filing Type' => REPORT_TYPES.values.grep(/year/i).reject{|v| v=~/termination/i},
        'Filing Year' => (2008..Date.today.year).map{ |y| y }
      }

      VALID_CONTRIBUTION_PARAMS = {
        'Filing Period' => ["Mid-Year", "Year-End"],
        #'Filing Type' => REPORT_TYPES.values.grep(/year/i).reject{|v| v=~/termination/i},
        #'Filing Year' => (2008..Date.today.year).map{ |y| y }
      }

  end
end
