require 'watir-webdriver'
require 'fileutils'
require 'date'

module Gucci
  module Senate
    class Search

      attr_accessor :download_dir, :search_params, :status, :pages, :filings

      def initialize(opts={})
        @search_type = opts[:contributions] ? :contributions : :disclosures
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
        urls = {:contributions => 'soprweb.senate.gov/index.cfm?event=lobbyistSelectFields&reset=1', :disclosures => 'soprweb.senate.gov/index.cfm?event=selectfields&reset=1' }
        browser.goto urls[:disclosures]
        return browser
      end

      def search(params)
        params.each_key do |param|
          @browser.checkbox(:value=>"#{param}").set
          sleep 1
        end
        @browser.button(:value=>"Submit").click
        begin
          params.each_pair do |param_key,param_value|
            if valid_params.keys.include?(param_key)
              @browser.select_list(:id=>"#{param_key}").option(:text=>"#{param_value}").select
            elsif param_key == "datePosted"
               make_date_params(param_value).each_pair do |date_key,date_value|
                @browser.text_field(:id => "#{date_key}").set "#{date_value}"
              end
            else
              @browser.text_field(:id => "#{param_key}").set "#{param_value}"
            end
            sleep 1
          end
          @browser.button(:value=>"Submit").click
        rescue Exception=>e
          puts "Something went wrong with the Submit"
          puts e.message #Error checking
        end
        raise ArgumentError, "There was an error with the Senate Lobby Disclosure Search System. Try your search again." if @browser.text.scan(/"An Error Occurred"/)[0] == "An Error Occurred"
        raise ArgumentError, "No records found, please refine your search or perform a new search." unless @browser.text.scan(/No Records Found/)[0].nil?
        begin
          @status = @browser.div(:id=>"searchResults_info").text.scan(/\d+ to \d+ of \d+,?\d* entries/)[0]
          raise ArgumentError, "Query returned #{@status.scan(/\d+/)[-1]} records. Cannot search for more than 3000 records. Please refine search." if @status.scan(/\d+/)[-1].to_i > 3000
          @entries = @status.scan(/of (.*?) entries/).flatten[0].gsub(',','').to_i
          @pages = @entries/100
          @pages +=1 if @entries%100 > 0
          @filings = parse_results
          return @browser
        rescue Exception=>e
          puts 'Something went wrong with the status check'
          puts e.message
          return @browser
        end
      end

      def parse_results()
        filings = []
        while @pages >0
          puts "Processing page #{@pages}" if @verbose
          rownum = 0
          @browser.trs(:class=>/(odd|even)/).each do |row|
            rownum+=1 if @verbose
            puts "Processing row #{rownum} from page #{@pages}" if @verbose
            newrow = []
            row.tds.each{|t|newrow.push(t.text)}
            filing_id = ''
            filing_id+=row.html
            newrow.unshift(filing_id.scan(/filingID\=(.*?)\&/)[0])
            filings.push(newrow.flatten)
          end
          @pages-=1
          @browser.span(:id=>"searchResults_next").click if @pages > 0
        end
        return filings
      end

      def results(&block)
        parsed_results = []
        disclosure_keys = [:filing_id, :registrant_name, :client_name, :filing_type, :amount_reported, :date_posted, :filing_year]
        contribution_keys = [:filing_id,:organization_name, :lobbyist_name,:filing_type, :filing_year, :date_posted ]
        keys = @search_type == :contributions ? contribution_keys : disclosure_keys
        @filings.each do |row| #should we call parse_results function directly or call a variable holding the returned filings?
          next if row.empty?
          search_result ||= Gucci::Mapper[*keys.zip(row).flatten]
          #puts search_result
          if block_given?
            yield search_result
          else
            parsed_results << search_result
          end
        end
        block_given? ? nil : parsed_results
      end

      def make_params(search_params)
        @search_type == :contributions ? make_contribution_params(search_params) : make_disclosure_params(search_params)
      end

      def make_disclosure_params(search_params)
        {#remake parameter values here or in validate_params?
        'registrantName' => search_params[:registrant_name] || '', #validate?
        'clientName' => search_params[:client_name] || '', #validate?
        'registrantID' => search_params[:registrant_id] || '', #validate?
        'clientID' => search_params[:client_id] || '', #validate?
        'filingPeriod' => search_params[:filing_period] || '',
        'reportType' => search_params[:filing_type] || '',
        'filingYear' => search_params[:filing_year] || '',
        'datePosted' => search_params[:date_posted] || '',
        'issueCode' => search_params[:issue_code] || '',
        'lobbyistName' => search_params[:lobbyist_name] || '', #validate?
        'affiliatedOrganizationCountry' => search_params[:affiliated_country] || '',
        'affiliatedOrganizationName' => search_params[:affiliated_name] || '', #validate?
        #'amountReported' => search_params[:amount_reported] || '', #validate?
        'clientCountry' => search_params[:client_country] || '',
        'clientPPBCountry' => search_params[:client_ppb_country] || '',
        'clientState' => search_params[:client_state] || '',
        'foreignEntityPPBCountry' => search_params[:foreign_entity_ppb_country] || '',
        'foreignEntityCountry' => search_params[:foreign_entity_country] || '',
        'foreignEntityName' => search_params[:foreign_entity_name] || '', #validate?
        #'foreignEntityOwnershipPercentage' => search_params[:foreign_entity_ownership] || '', #validate?
        'governmentEntityContacted' => search_params[:government_entity] || '', #validate?
        'lobbyingIssue' => search_params[:issue_data] || '', #validate?
        'lobbyistCoveredGovernmentPositionDescription' => search_params[:lobbyist_covered] || '',
        'lobbyistCoveredPositionDescription' => search_params[:lobbyist_position] || '', #validate?
        'registrantCountry' => search_params[:registrant_country] || '',
        'registrantPPBCountry' => search_params[:registrant_ppb_country] || ''
        }
      end

      def make_date_params(date_params)
        {
          'datePostedStart' => date_params[:start] || Date.today.strftime('%m/%d/%Y'),
          'datePostedEnd' => date_params[:end] || Date.today.strftime('%m/%d/%Y')
        }
      end

      def make_contribution_params(search_params)
        {
        'registrantName' => search_params[:registrant_name] || '',
        'registrantLobbyistName' => search_params[:registrant_name_with_lobbyists] || '',
        'lobbyistName' => search_params[:lobbyist_name] || '',
        'reportType' => search_params[:filing_type] || '',
        'filingDate' => search_params[:date_posted] || '',
        'filingYear' => search_params[:filing_year] || '',
        'pac' => search_params[:contributor_name] || '',
        'payee' => search_params[:payee_name] || '',
        'honoree' => search_params[:honoree_name] || '',
        'contributionType' => search_params[:contribution_type] || '',
        'contributionDate' => search_params[:contribution_date] || ''
        }
      end

      def valid_params
        @search_type == :contributions ? VALID_CONTRIBUTION_PARAMS : VALID_DISCLOSURE_PARAMS
      end

      def validate_params(params)
        raise ArgumentError, "At least one search parameter must be given, possible parameters are #{valid_params.keys.join(', ')}" if params.values.all? { |x| x.to_s.empty? }
        params.delete_if { |k,v| v.to_s.empty? }
        #change any parameter keys here to match what the form expects?
        raise ArgumentError, "No more than five search parameters are permitted" if params.keys.count > 5
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
        "RR" => "REGISTRATION",
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
        'filingPeriod' => ["Mid-Year (Jan 1 - Jun 30)", "Year-End (July 1 - Dec 31)", "1st Quarter (Jan 1 - Mar 31)", "2nd Quarter (Apr 1 - June 30)", "3rd Quarter (July 1 - Sep 30)", "4th Quarter (Oct 1 - Dec 31)"],
        'reportType' => REPORT_TYPES.values,
        'filingYear' => (1999..Date.today.year).map{ |y| y },
        'issueCode' => ISSUES.values,
        'affiliatedOrganizationCountry' => COUNTRIES.values,
        'clientCountry' => COUNTRIES.values,
        'clientPPBCountry' => COUNTRIES.values,
        'clientState' => STATES,
        'foreignEntityPPBCountry' => COUNTRIES.values,
        'foreignEntityCountry' => COUNTRIES.values,
        'lobbyistCoveredPositionDescription' => ["True","False"],
        'registrantCountry' => COUNTRIES.values,
        'registrantPPBCountry' => COUNTRIES.values
      }

      VALID_CONTRIBUTION_PARAMS = {
        'Filing Period' => ["Mid-Year", "Year-End"],
        'Filing Type' => REPORT_TYPES.values.grep(/year/i).reject{|v| v=~/termination/i},
        'Filing Year' => (2008..Date.today.year).map{ |y| y }
      }

  end
end
