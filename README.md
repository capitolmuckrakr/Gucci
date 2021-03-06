# NOTE: UNMAINTAINED AND LIMITED FUNCTIONALITY. CHANGES IN THE HOUSE LOBBYING WEBSITE HAVE BROKEN THE DOWNLOAD AND SEARCH FUNCTIONS. I'M REWRITING THE PROJECT IN PYTHON TO WORK WITH THE NEW HOUSE LOBBYING SITE (UNLESS THEY CHANGE IT AGAIN :} ).

# Gucci

Gucci is a Ruby library for searching, downloading and parsing lobbying and contribution filings from the Clerk of the House of Representatives. The structure and function are heavily indebted to [Fech](https://github.com/NYTimes/Fech) and [fech-search](https://github.com/huffpostdata/fech-search), Ruby libraries for parsing and searching FEC campaign filings.

Gucci::House::Search is a wrapper around the [lobbying](http://disclosures.house.gov/ld/ldsearch.aspx) and [contribution](http://disclosures.house.gov/lc/lcsearch.aspx) search forms on the Clerk's website.

Gucci::House::Filing creates an object corresponding to an electronic filing from the Clerk, either a lobbying registration (LD-1), a lobbying report (LD-2) or a contribution disclosure (LD-203).

Gucci is named after one of the seminal works of lobbying reporting, [Showdown at Gucci Gulch](http://www.amazon.com/Showdown-Gucci-Gulch-Alan-Murray/dp/0394758110).

## Installation

Searching with Gucci uses [firefox](https://www.mozilla.org/en-US/firefox/) and [geckodriver](https://github.com/mozilla/geckodriver/releases/latest), both of which must be installed and accessible on your system's path.

Gucci was mostly developed on Ubuntu 12.04 using Ruby 2.1.1, but will work on Ruby versions 1.9.2 and later. Gucci has received limited testing on Apple's OS 10.9 and has not been tested on Windows.

To install on Ubuntu:

    
    git clone https://github.com/capitolmuckrakr/Gucci.git
    cd Gucci
    bundle install
    rake install
    

## Usage

### Examples

    require 'gucci'

#### Searching

A. Lobbying filing disclosures

Perform a search for form LD-1 or LD-2 filings (lobbying registrations and lobbying activity reports) submitted for Lockheed Martin in 2019:

    search = Gucci::House::Search.new(:client_name => "Lockheed Martin", :filing_year => 2019)

B. Contribution filing disclosures

Perform a search for form LD-203 filings submitted by Lockheed Martin and its individual lobbyists in 2019:

    search = Gucci::House::Search.new(:organization_name => "Lockheed Martin", :filing_year => 2019, :contributions => true)

C. Contributions search

Perform a search for honorary contributions and payments to Sen. Chuck Grassley listed on multiple form LD-203 filings:

    search = Gucci::House::Search.new(:honoree=>"Grassley",:contribution_type=>"Honorary",:contributions=>"contributions")

The search is performed when `Gucci::House::Search.new` is called. You can then access the results of the search with `search.results`, an array of search result objects:

    results = search.results
    results.size
    => 100

Each result object has the following attributes:

For lobbying filings:
- filing_id
- registrant_id
- registrant_name
- client_name
- filing_year
- filing_period
- lobbyists

For contribution filings:
- filing_id
- house_id
- organization_name
- remaining_items (the order of the columns returned after the previous columns varies, the Clerk's office apparently determines the order based on the search criteria used)

For contribution searches:
- filing_id (the data matching a search query isn't always in the included attributes, in which case you'll have to load the matching filing using its filing_id)
- house_id
- organization_name
- lobbyist_name (other data may appear in this field instead)
- payee_name (other data may appear in this field instead)
- recipient_name (other data may appear in this field instead)
- contributor_name (other data may appear in this field instead)
- amount (other data may appear in this field instead)

Create a `Gucci::House::Filing` object from one of the results and download the filing data:

    filing = Gucci::House::Filing.new(results.first.filing_id).download

#### Parsing

Create a Filing object that corresponds to an electronic filing in XML format from the Clerk, using the unique numeric identifier that the Clerk assigns to each filing. You'll then have to download the file before parsing it:

    filing = Gucci::House::Filing.new(300645953)

    filing.download

Optionally, you can specify the :download_dir on initialization to set where filings are stored. Otherwise, they'll go into a temp folder on your filesystem.

To get summary attributes for the filing (total lobbying spending, organization or person submitting the filing, other stats about the filing):

    filing.summary
    => {:imported=>"N", :pages=>"17", :submitURL=>nil, :organizationName=>"LOCKHEED MARTIN CORPORATION", ... }

Returns a named hash of summary attributes available for the filing. Attributes are dynamically assigned based on the type of filing being parsed and on the contents of the filing itself. To see the filing type:

    filing.filing_type
    => :lobbyingdisclosure2
    
Attributes can be called as methods instead of using symbols as keys:

    filing.summary.clientName
    => "Marinette Marine Corporation"

Other attributes, accessible using .body, are stored as arrays of named hashes, as arrays, or as strings.

    filing.body.issues.first
    => {:issueAreaCode=>"CAW", :specific_issues=>"CAC meetings about state work on methane and power
    plant rules,  Senate DPC meeting, and internal legislative meetings.", :federal_agencies=>
    ["U.S. SENATE","U.S. HOUSE OF REPRESENTATIVES"], :foreign_entity_issues=>nil, :lobbyists=>
    [{:lobbyistFirstName=>"Lana", :lobbyistLastName=>"Lobbyist", :lobbyistSuffix=>nil,
    :coveredPosition=>nil, :lobbyistNew=>"N"}, {:lobbyistFirstName=>"Bob", :lobbyistLastName=>"Loblaw",
    :lobbyistSuffix=>nil, :coveredPosition=>nil, :lobbyistNew=>"N"}]}
    
Again, body attributes and their descendants are accessible as method calls:

    filing.body.issues.first.federal_agencies
    => ["U.S. HOUSE OF REPRESENTATIVES", "U.S. SENATE"]

##### Helper methods
Gucci doesn't do a lot to process the data it reads, in case of parsing errors. There are a couple of methods to cleanup returned data:
- String#to_strtime --converts a string in datetime format to a Ruby datetime object
- Hash#empty_record? --returns a boolean value

### Search parameters

The following search parameters are available for lobbying filings:

- `:registrant_name`
- `:client_name`
- `:registrant_id`
- `:filing_period`
- `:filing_type`
- `:filing_year`
- `:issue_code`
- `:lobbyist_name`
- `:affiliated_country`
- `:affiliated_name`
- `:amount_reported`
- `:client_country`
- `:client_ppb_country`
- `:client_state`
- `:foreign_entity_ppb_country`
- `:foreign_entity_country`
- `:foreign_entity_name`
- `:foreign_entity_ownership`
- `:government_entity`
- `:issue_data`
- `:lobbyist_covered`
- `:lobbyist_position`
- `:lobbyist_inactive`
- `:registrant_country`
- `:registrant_ppb_country`

To search for contribution filings, set the contributions flag:

    :contributions => true

The following search parameters are available for contribution filings:

- `:organization_name`
- `:house_id`
- `:filing_period`
- `:filing_type`
- `:pac`
- `:filing_year`
- `:lobbyist_name`
- `:contact_name`
- `:senate_id`

Details for specific contributions can be searched as well by setting the contributions flag to "contributions":

    :contributions => "contributions"

The following search parameters are available for contribution searches:

- `:organization_name`
- `:house_id`
- `:filing_period`
- `:contribution_type`
- `:lobbyist_name`
- `:honoree`
- `:payee_name`
- `:contributor_name`
- `:amount`
- `:senate_id`

Up to five parameters may be used and the search functionality will return up to 2,000 results. An error is returned if too many parameters are passed or if a parameter is set to an invalid value. Any invalid parameters are ignored.

    search = Gucci::House::Search.new(:filing_year => 2020)
    ArgumentError: 1 error(s)
    2020 is invalid for Filing Year, permitted values are 2014, 2015, 2016, 2017, 2018, 2019

### Filing attributes
*Attributes are dynamically assigned and may vary for different filings of the same type*

Lobbying registration filings (LD-1):

- `:filing_url`
- `:filing_id`
- `:filing_type`
- `:summary`
    - `:imported`
    - `:pages`
    - `:organizationName`
    - `:prefix`
    - `:firstName`
    - `:lastName`
    - `:address1`
    - `:address2`
    - `:city`
    - `:state`
    - `:zip`
    - `:zipext`
    - `:country`
    - `:principal_city`
    - `:principal_state`
    - `:principal_zip`
    - `:principal_zipext`
    - `:principal_country`
    - `:selfSelect`
    - `:clientName`
    - `:senateID`
    - `:houseID`
    - `:reportYear`
    - `:reportType`
    - `:printedName`
    - `:signedDate`
    - `:regType`
    - `:contactIntlPhone`
    - `:registrantGeneralDescription`
    - `:clientAddress`
    - `:clientCity`
    - `:clientState`
    - `:clientZip`
    - `:clientZipExt`
    - `:clientCountry`
    - `:prinClientCity`
    - `:prinClientState`
    - `:prinClientZip`
    - `:prinClientZipExt`
    - `:prinClientCountry`
    - `:clientGeneralDescription`
    - `:specific_issues`
    - `:affiliatedUrl`
    - `:effectiveDate`
- `:body`
    - `:lobbyists` Array
        - `:lobbyistFirstName`
        - `:lobbyistLastName`
        - `:lobbyistSuffix`
        - `:coveredPosition`
        - `:lobbyistNew`
    - `:affiliatedOrgs` Array
        - `:affiliatedOrgName`
        - `:affiliatedOrgAddress`
        - `:affiliatedOrgCity`
        - `:affiliatedOrgState`
        - `:affiliatedOrgZip`
        - `:affiliatedOrgCountry`
        - `:affiliatedPrinOrgCity`
        - `:affiliatedPrinOrgState`
        - `:affiliatedPrinOrgCountry`
    - `:foreignEntities` Array
        - `:name`
        - `:address`
        - `:city`
        - `:state`
        - `:country`
        - `:prinCity`
        - `:prinState`
        - `:prinCountry`
        - `:contribution`
        - `:ownership_Percentage`
    - `:issues` Array


Lobbying disclosure filings (LD-2):
- `:filing_url`
- `:filing_id`
- `:filing_type`
- `:summary`
    - `:imported`
    - `:pages`
    - `:organizationName`
    - `:prefix`
    - `:firstName`
    - `:lastName`
    - `:address1`
    - `:address2`
    - `:city`
    - `:state`
    - `:zip`
    - `:zipext`
    - `:country`
    - `:principal_city`
    - `:principal_state`
    - `:principal_zip`
    - `:principal_zipext`
    - `:principal_country`
    - `:selfSelect`
    - `:clientName`
    - `:senateID`
    - `:houseID`
    - `:reportYear`
    - `:reportType`
    - `:printedName`
    - `:signedDate`
    - `:submitURL`
    - `:registrantDifferentAddress`
    - `:clientGovtEntity`
    - `:terminationDate`
    - `:noLobbying`
    - `:income`
    - `:expenses`
    - `:expensesMethod`
- `:body`
    - `:issues` Array
        - `:issueAreaCode`
        - `:specific_issues`
        - `:federal_agencies` Array
        - `:foreign_entity_issues` Array
        - `:lobbyists` Array
            - `:lobbyistFirstName`
            - `:lobbyistLastName`
            - `:lobbyistSuffix`
            - `:coveredPosition`
            - `:lobbyistNew`
    - `:updates`
        - `:clientAddress`
        - `:clientCity`
        - `:clientState`
        - `:clientZip`
        - `:clientZipext`
        - `:clientCountry`
        - `:prinClientCity`
        - `:prinClientState`
        - `:prinClientZip`
        - `:prinClientZipext`
        - `:prinClientCountry`
        - `:generalDescription`
        - `:inactive_lobbyists` Array
        - `:inactive_ALIs` Array
        - `:affiliatedUrl`
        - `:affiliatedOrgs` Array
        - `:inactiveOrgs` Array
        - `:foreignEntities` Array
        - `:inactive_ForeignEntities` Array

Contribution filings (LD-203):

- `:filing_url`
- `:filing_id`
- `:filing_type`
- `:summary`
    - `:filerType`
    - `:organizationName`
    - `:lobbyistPrefix`
    - `:lobbyistFirstName`
    - `:lobbyistMiddleName`
    - `:lobbyistLastName`
    - `:lobbyistSuffix`
    - `:contactName`
    - `:senateRegID`
    - `:houseRegID`
    - `:reportYear`
    - `:reportType`
    - `:amendment`
    - `:comments`
    - `:signedDate`
    - `:certifiedcontent`
    - `:noContributions`
- `:body`
    - `:contributions` Array
        - `:type`
        - `:contributorName`
        - `:payeeName`
        - `:recipientName`
        - `:amount`
        - `:date`
- `:pacs`



## Author

- Alexander Cohen, alex@capitolmuckraker.com

## Contributing

1. Fork it ( http://github.com/capitolmuckrakr/Gucci/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create new Pull Request
