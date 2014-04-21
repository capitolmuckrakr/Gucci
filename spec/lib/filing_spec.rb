require 'spec_helper'

describe Gucci do

  #before do
    #@registration = Gucci::House::Filing.new(300611018,:download_dir=>File.join(File.dirname(__FILE__), 'data')
    #@registration.stubs(:file_path).returns(File.join(File.dirname(__FILE__), 'data', '300611018.xml'))
    #@report = Gucci::House::Filing.new(300630565,:download_dir=>File.join(File.dirname(__FILE__), 'data')
    #@report.stubs(:file_path).returns(File.join(File.dirname(__FILE__), 'data', '300630565.xml'))
    #@contribution = Gucci::House::Filing.new(700704476,:download_dir=>File.join(File.dirname(__FILE__), 'data')
    #@contribution.stubs(:file_path).returns(File.join(File.dirname(__FILE__), 'data', '700704476.xml'))
  #end

  it "should return a filing object" do
    @filing = Gucci::Filing.new(300630565,:download_dir=>File.join(File.dirname(__FILE__), 'data'))
    @filing.should_not be_nil
  end

  #describe "#summary" do

    #it "should return the mapped summary row" do
      #sum = @report.summary
      #sum.should be_a_kind_of(Hash)
      #sum[:clientName].should == "Environmental Defense Action Fund"
    #end
  #end

end