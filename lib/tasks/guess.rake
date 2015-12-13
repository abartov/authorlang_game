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
def print_stats
  total = Author.count
  guess_ready = Author.where(status: READY_FOR_HUMAN).count
  done = Author.where(status: DONE).count
  assigned = Author.where(status: ASSIGNED).count
  no_guess = Author.where(status: NO_GUESS).count
  puts "Of a total of #{total} authors originally without P1412:\n#{guess_ready} guesses ready; #{done} done; #{assigned} assigned; #{no_guess} with no guess"
end
