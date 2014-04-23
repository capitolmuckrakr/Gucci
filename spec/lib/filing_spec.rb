require 'spec_helper'

describe Gucci do

  before do
    @registration = Gucci::House::Filing.new(300611018,:download_dir=>File.join(File.dirname(__FILE__), 'data'))
    @registration.stubs(:file_path).returns(File.join(File.dirname(__FILE__), 'data', '300611018.xml'))
    @report = Gucci::House::Filing.new(300630565,:download_dir=>File.join(File.dirname(__FILE__), 'data'))
    @report.stubs(:file_path).returns(File.join(File.dirname(__FILE__), 'data', '300630565.xml'))
    #@contribution = Gucci::House::Filing.new(700704476,:download_dir=>File.join(File.dirname(__FILE__), 'data')
    #@contribution.stubs(:file_path).returns(File.join(File.dirname(__FILE__), 'data', '700704476.xml'))
  end

  it "should return a report filing object" do
    @filing = Gucci::House::Filing.new(300630565,:download_dir=>File.join(File.dirname(__FILE__), 'data'))
    @filing.should_not be_nil
  end

  describe "#report_summary" do

    it "should return the report mapped summary row" do
      sum = @report.summary
      sum.should be_a_kind_of(Hash)
      sum.clientName.should == "Environmental Defense Action Fund"
    end
  end

  describe "#report_issues" do

    it "should return an array" do
      iss = @report.issues
      iss.should be_a_kind_of(Array)
    end
  end

  describe "#report_issue" do

    it "should return a mapped issue row" do
      iss1 = @report.issues.first
      iss1.should be_a_kind_of(Hash)
      iss1.issueAreaCode.should == "CAW"
    end
  end
  
  describe "#report_lobbyists" do

    it "should return an array" do
      lob = @report.issues.first.lobbyists
      lob.should be_a_kind_of(Array)
    end
  end
  
  describe "#report_lobbyist" do

    it "should return a mapped lobbyist row" do
      lob = @report.issues.first.lobbyists
      lob.sort_by!{|v| v.lobbyistLastName}
      lob1 = lob.first
      lob1.should be_a_kind_of(Hash)
      lob1.lobbyistLastName.should == "Andress"
    end
  end

  describe "#report_updates" do

    it "should return the report mapped update row" do
      ups = @report.updates
      ups.should be_a_kind_of(Hash)
      ups.clientAddress.should == nil
    end
  end
  
  describe "#report_inactive_lobbyists" do

    it "should return an array" do
      inact_lobs = @report.updates.inactive_lobbyists
      inact_lobs.should be_a_kind_of(Array)
      inact_lobs.count.should == 2
    end
  end
  
  describe "#report_inactive_lobbyist" do

    it "should return a mapped inactive lobbyist row" do
      inact_lobs = @report.updates.inactive_lobbyists
      inact_lobs.sort_by!{|v| v.lastName}
      inact_lob1 = inact_lobs.first
      inact_lob1.should be_a_kind_of(Hash)
      inact_lob1.lastName.should == "Carey"
    end
  end  

end