# Gucci

Gucci provides a way to search, download and parse lobbying and lobbyist contribution filings from the Clerk of the House of Representatives.

Gucci::House::Search is a Ruby wrapper around the lobbying and contribution search forms on the Clerk's website (http://disclosures.house.gov/ld/ldsearch.aspx and http://disclosures.house.gov/lc/lcsearch.aspx).

## Usage

### Examples

    require 'gucci'

I. Lobbying disclosures

Perform a search for form LD1 or LD2 filings (lobbying registrations and lobbying activity reports) submitted for Lockheed Martin in 2013:

    search = Gucci::House::Search.new(:client_name => "Lockheed Martin", :filing_year =2013


The search is performed when `Gucci::House::Search.new` is called. You can then access the results of the search with `search.results`, which is simply an array of search result objects:

    results = search.results
    results.size
    => 100

Each `Fech::SearchResult` object has the following attributes:

- amended_by
- committee_id
- committee_name
- date_filed
- date_format
- description
- filing_id
- form_type
- period

You can now work with the results as you would any Ruby array.

Remove any filings that have been amended:

    results.select! { |r| r.amended_by.nil? }
    results.size
    => 41

Limit to filings covering the last six months of 2012:

    results.select! { |r| r.period[:from] >= Date.new(2012, 7, 1) && r.period[:to] <= Date.new(2012, 12, 31) }
    results.size
    => 6

Create a `Fech::Filing` object from one of the results and download the filing data:

    filing = results.first.filing.download

You now have access to the same filing object and methods as if you had created it directly with [Fech](http://nytimes.github.io/Fech/).

To initialize the `Fech::Filing` object with parameters, pass them as arguments to the `SearchResult#filing` method:

    filing = results.first.filing(:csv_parser => Fech::CsvDoctor)

Get information from the filing:

    filing.summary[:col_a_total_receipts]
    => "4747984.49"

    filing.summary[:col_b_total_receipts]
    => "10617838.18"

### Search parameters

The following search parameters are available for lobbying disclosures:

-`:registrant_name`
-`:client_name`
-`:house_id`
-`:filing_period`
-`:filing_type`
-`:filing_year`
-`:issue_code`
-`:lobbyist_name`
-`:affiliated_country`
-`:affiliated_name`
-`:amount_reported`
-`:client_country`
-`:client_ppb_country`
-`:client_state`
-`:foreign_entity_ppb_country`
-`:foreign_entity_country`
-`:foreign_entity_name`
-`:foreign_entity_ownership`
-`:government_entity`
-`:issue_data`
-`:lobbyist_covered`
-`:lobbyist_position`
-`:lobbyist_inactive`
-`:registrant_country`
-`:registrant_ppb_country`


  

Up to five of these parameters may be used. However, the FEC's search functionality has some limitations:

- All other parameters are ignored when `:committee_id` is used.
- `:form_type` cannot be used by itself; another parameter must be used with it.

An `ArgumentError` will be raised if either of these is violated with `Fech::Search.new`.

__Note:__ Overly broad searches can be slow, so you should make your search as specific as possible.

## Installation

Add this line to your application's Gemfile:

    gem 'fech-search'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fech-search

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Authors

- Alexander Cohen, alex@capitolmuckraker.com

## Copyright

Copyright © 2014 The Center for Public Integrity. See LICENSE for details.
