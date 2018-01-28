# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "coffee_table/version"

Gem::Specification.new do |s|
  s.name        = "coffee_table"
  s.version     = CoffeeTable::VERSION
  s.authors     = ["Stewart McKee"]
  s.email       = ["stewart@theizone.co.uk"]
  s.homepage    = ""
  s.summary     = "Gem to manage cache stored in redis"
  s.description = "rails cache gem to fragment cache with smart cache key management"

  s.rubyforge_project = "coffee_table"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_development_dependency "mock_redis"
  s.add_development_dependency "spork"
  s.add_development_dependency "coveralls"
  s.add_dependency "redis"
  s.add_dependency "redis-namespace"
  s.add_dependency "activesupport"
  s.add_dependency "sourcify"
  s.add_dependency "gzip"

end
