#require "yaml"
require 'authorlang'
include Authorlang

desc "come up with guesses for up to <max> authors"
task :guess, [:maxnum] => :environment do |taskname, args|
  args.with_defaults(maxnum: 10)
  guess_langs(args.maxnum)
end

