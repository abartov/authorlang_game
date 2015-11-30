#require "yaml"
require 'authorlang'
include Authorlang

desc "come up with guesses for up to <max> authors"
task :guess, [:maxnum] => :environment do |taskname, args|
  args.with_defaults(maxnum: 10)
  print_stats
  guess_langs(args.maxnum)
  print_stats
end
protected
def print_stats
  guess_ready = Author.where(status: READY_FOR_HUMAN).count
  done = Author.where(status: DONE).count
  assigned = Author.where(status: ASSIGNED).count
  puts "#{guess_ready} guesses ready; #{done} done; #{assigned} assigned"
end
