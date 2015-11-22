require 'linkeddata'
#require 'qlabel'
#require 'mediawiki_api'
#require 'wikidata'

# decisions
YES = 1
NO = 0

# heuristics
NOTABLE_WORK = 1
CITIZENSHIP = 2

# statuses
NONE = 0
NO_GUESS = 1
READY_FOR_HUMAN = 2
DONE = 3

module Authorlang
  def ingest
    puts "querying..."
    sparql = SPARQL::Client.new("https://query.wikidata.org/bigdata/namespace/wdq/sparql", :method => :get)
    res = sparql.query("PREFIX wd: <http://www.wikidata.org/entity/>
      PREFIX wdt: <http://www.wikidata.org/prop/direct/>
      SELECT ?aid WHERE { 
        { ?aid wdt:P106 wd:Q49757 } UNION {?aid wdt:P106 wd:Q214917} UNION {?aid wdt:P106 wd:Q36180}
        MINUS { ?aid wdt:P1412 ?lang }
      }")
    puts "#{res.count} results found. Processing..."
    i = 0
    res.each {|item|
      puts "#{i} items processed. #{i/res.count.to_f*100}% done." if i % 200 == 0
      uri = item['aid'].to_s
      qnum = uri[uri.rindex('/')+2..-1]
      auth = Author.find_by_qid(qnum)
      if auth.nil?
        auth = Author.new(qid: qnum, status: NONE)
        auth.save!
      end
      i += 1
    }
    puts "done."
  end

  def guess_langs(max)
    puts "coming up with some guesses..."
    a = Author.where(status: NONE).limit(max)
    return if a.nil?
    a.each {|auth| 
     puts "attempting to guess a language for Q#{auth.qid}"
     guess = guess_lang(auth)
     if guess.empty?
       auth.status = NO_GUESS
     else
       auth.guess = guess[:guess]
       auth.heuristic = guess[:heuristic]
       auth.status = READY_FOR_HUMAN
     end
     auth.save!
    }
  end

  def guess_lang(author)
    ret = {}
    # heuristics
    item = Wikidata::Item.find("Q#{author.qid}")
    # by language of associated work?
    works = item.properties("P800") # notable works
    if works.count > 0
      worklangs = works.first.properties('P364') # original language
      if worklangs.count > 0
        return {heuristic: NOTABLE_WORK, guess: worklangs.first.id[1..-1].to_i} # offer language of notable work as a guess
      end
    end
    # by country?
    countries = item.properties("P27")
    if countries.count == 1
      country = countries.first
      off_langs = country.properties("P37")
      if off_langs.count > 0
        # some countries (e.g. USA) don't have an official language
        unless off_langs.first.nil?
          return {heuristic: CITIZENSHIP, guess: off_langs.first.id[1..-1].to_i} # offer first official language as a guess
        end
      end
    end # TODO: anything intelligent we can guess if more than one country listed? 
    #  
    return ret
  end
end
