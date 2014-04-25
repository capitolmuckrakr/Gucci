require 'spec_helper'

describe Gucci do

  context "creating" do

    it "should raise ArgumentError if no parameters are given" do
      expect { Gucci::House::Search.new }.to raise_error(ArgumentError)
    end

    #it "should raise ArgumentError if :form_type is given without another parameter" do
    #  expect { Fech::Search.new(:form_type => "F3") }.to raise_error(ArgumentError)
    #end

    #it "should not raise an error if :committee_id is given by itself" do
    #  expect { Fech::Search.new(:committee_id => "C00431171") }.to_not raise_error(ArgumentError)
    #end

    #it "should not raise an error if :form_type is given with another parameter" do
    #  expect { Fech::Search.new(:form_type => "F3", :date => Date.new(2013, 5, 29)) }.to_not raise_error(ArgumentError)
    #end

  end

  context "results" do

    it "should return an array of results" do
      search = Gucci::House::Search.new(:filing_year => Date.today.year, :issue_code => "DEFENSE")
      search.results.class.should be_a_kind_of(Array)
      search.results.first.class.should == Gucci::Mapper
    end
    
  end

end