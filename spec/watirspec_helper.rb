require 'watirspec'
# require your gems

WatirSpec.implementation do |watirspec|
  # add WatirSpec implementation (see example below)
  #
  # watirspec.name = :watizzle
  # watirspec.browser_class = Watir::Browser
  # watirspec.browser_args = [:phantomjs, {}]
  # watirspec.guard_proc = lambda do |args|
  #   args.include?(:phantomjs)
  # end
end

WatirSpec.run!
