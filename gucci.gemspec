# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gucci/version'

Gem::Specification.new do |spec|
  spec.name          = "gucci"
  spec.version       = Gucci::VERSION
  spec.authors       = ["acohen"]
  spec.email         = ["alex@capitolmuckraker.com"]
  spec.summary       = %q{A Ruby library for searching and parsing lobbying filings}
  spec.description   = %q{A Ruby library for interacting with electronic filings from the Clerk of the House of Representatives}
  spec.homepage      = ""
  spec.license     = "Apache-2.0"

  spec.rubyforge_project = "gucci"

  spec.files         = `git ls-files`.split("\n")
  spec.executables   = `git ls-files -- {spec}/*`.split("\n")
  spec.test_files    = `git ls-files -- {spec}/*`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_dependency 'nokogiri'
  spec.add_dependency 'ensure-encoding'
  spec.add_dependency 'watir-webdriver'
  spec.add_dependency 'headless'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "mocha"
end
