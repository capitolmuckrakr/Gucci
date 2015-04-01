require "gucci/version"
require "gucci/house/filing"
require "gucci/senate/filing"
require "gucci/house/search"
require "gucci/senate/search"
require "gucci/mapper"
require 'tmpdir'

module Gucci
  FILING_TYPES = [:contributiondisclosure,:lobbyingdisclosure1,:lobbyingdisclosure2]
  module House
    class Search
    end
    class Filing
    end
  end
  module Senate
    class Search
    end
    class Filing
    end
  end
end
