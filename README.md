# Gucci

Gucci is a Ruby library for searching, downloading and parsing lobbying and contribution filings from the Clerk of the House of Representatives. The structure and function is heavily indebted to [Fech](https://github.com/NYTimes/Fech) and [fech-search](https://github.com/huffpostdata/fech-search), Ruby libraries for parsing and searching FEC campaign filings.

Gucci::House::Search is a wrapper around the [lobbying](http://disclosures.house.gov/ld/ldsearch.aspx) and [contribution](http://disclosures.house.gov/lc/lcsearch.aspx) search forms on the Clerk's website.

Gucci::House::Filing creates an object corresponding to an electronic filing from the Clerk, either a lobbying registration (LD1), a lobbying report (LD2) or a contribution disclosure (LD203).

Gucci is named after one of the seminal works of lobbying reporting, [Showdown at Gucci Gulch](http://www.amazon.com/Showdown-Gucci-Gulch-Alan-Murray/dp/0394758110).

## Installation

Searching with Gucci uses Selenium and Firefox for headless browsing and is limited to platforms that support Xvfb, including Ubuntu and OSX using Macports only, not Homebrew. Changing that is on the list of tasks for the project.

Otherwise, the software is functional, though still in development.

Gucci was mostly developed on Ubuntu 12.04 using Ruby 2.1.1, but will work on Ruby versions 1.9.2 and later. If installing on Ubuntu server, Gucci needs Firefox to run. Gucci has received limited testing on OS 10.9 and has not been tested on Windows.

To install on Ubuntu 12.04 or greater:

    sudo apt-get install xvfb

    export DISPLAY=:99 # add this to your environment so that xvfb won't conflict with any other displays

    git clone https://github.com/capitolmuckrakr/Gucci.git

    bundle install

## Usage

### Examples

    require 'gucci'

#### Searching

A. Lobbying disclosures

Perform a search for form LD1 or LD2 filings (lobbying registrations and lobbying activity reports) submitted for Lockheed Martin in 2013:

    search = Gucci::House::Search.new(:client_name => "Lockheed Martin", :filing_year => 2013)

B. Contribution disclosures

Perform a search for form LD203 filings submitted by Lockheed Martin and its individual lobbyists in 2013:

    search = Gucci::House::Search.new(:organization_name => "Lockheed Martin", :filing_year => 2013, :contributions => true)

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
- remaining_items

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

Other attributes, accessible using .body, are stored as arrays of named hashes, as arrays, or as strings, such as lobbyists and contributions (hashes), pacs and agencies(arrays) and specific issues(string).

    filing.body.issues.first
    => {:issueAreaCode=>"CAW", :specific_issues=>"CAC meetings about state work on methane
    and power plant rules,  Senate DPC meeting, and internal legislative meetings.\n\nNote:
    Registrants lobbied one or more of the agencies noted.", :federal_agencies=>["U.S. SENATE",
    "U.S. HOUSE OF REPRESENTATIVES", "Environmental Protection Agency (EPA)"],
    :foreign_entity_issues=>nil, :lobbyists=>[{:lobbyistFirstName=>"Lana",
    :lobbyistLastName=>"Lobbyist", :lobbyistSuffix=>nil, :coveredPosition=>nil, :lobbyistNew=>"N"},
    {:lobbyistFirstName=>"Bob", :lobbyistLastName=>"Loblaw", :lobbyistSuffix=>nil,
    :coveredPosition=>nil, :lobbyistNew=>"N"}]}

### Search parameters

The following search parameters are available for lobbying filings:

- `:registrant_name`
- `:client_name`
- `:house_id`
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

To do a search for contribution filings, set the contributions flag:

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

Up to five parameters may be used and the search functionality will return up to 2,000 results.


## Author

- Alexander Cohen, alex@capitolmuckraker.com

## Copyright

Copyright © 2014 The Center for Public Integrity. See LICENSE for details.
