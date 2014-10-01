require 'spec_helper'

describe Gucci do

  describe "creating search" do

    it "should raise ArgumentError if no parameters are given" do
      expect { Gucci::House::Search.new }.to raise_error(ArgumentError)
    end

  end

  describe "search results" do

    it "should return an array of results" do
      search = Gucci::House::Search.new(:filing_year => Date.today.year, :issue_code => "DEFENSE")
      expect(search.results).to be_a_kind_of(Array)
    end

    #it "should raise ArgumentError if more than 2000 search results are returned" do
    #  expect { Gucci::House::Search.new(:filing_year => 2013) }.to raise_error(ArgumentError)
    #end

  end

end