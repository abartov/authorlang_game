#require "yaml"
require 'authorlang'
include Authorlang

desc "ingest authors without P1412 from Wikidata"
task :ingest => :environment do |taskname, args|
  ingest
end

