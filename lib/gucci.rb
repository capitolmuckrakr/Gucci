require "gucci/version"
require "gucci/filing"
require "gucci/search"

module Gucci
  def self.search(opts={})
    Search.new(opts={})
  end
  def self.filing(filing_id,opts={})
    Filing.new(filing_id,opts={})
  end
end
