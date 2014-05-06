# Gucci

Gucci is a Ruby library for searching, downloading and parsing lobbying and contribution filings from the Clerk of the House of Representatives.

Gucci::House::Search is a wrapper around the lobbying and contribution search forms on the Clerk's website (http://disclosures.house.gov/ld/ldsearch.aspx and http://disclosures.house.gov/lc/lcsearch.aspx).

Gucci::House::Filing creates an object corresponding to an electronic filing from the Clerk, either a lobbying registration (LD1), a lobbying report (LD2) or a contribution disclosure (LD203).

## Usage

### Examples

    require 'gucci'

I. Searching

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

Up to five parameters may be used and the search functionality will only return up to 2,000 results.

## Installation

Add this line to your application's Gemfile:

    gem 'gucci'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gucci

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

- Alexander Cohen, alex@capitolmuckraker.com

## Copyright

Copyright © 2014 The Center for Public Integrity. See LICENSE for details.
