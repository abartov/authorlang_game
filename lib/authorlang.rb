require 'linkeddata'
#require 'qlabel'
require 'mediawiki_api'
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
ASSIGNED = 3
DONE = 4

# some hard-coded Q numbers for some optimizations
Q_ENGLISH = 1860
Q_USA = 30
Q_BELGIUM = 31
Q_INDIA = 668
Q_GERMAN = 188
Q_FRENCH = 150

module Authorlang
  def ingest
    puts "querying..."
    sparql = SPARQL::Client.new("https://query.wikidata.org/bigdata/namespace/wdq/sparql", :method => :get)
    res = sparql.query("PREFIX wd: <http://www.wikidata.org/entity/>
      PREFIX wdt: <http://www.wikidata.org/prop/direct/>
      SELECT ?aid WHERE { 
        { ?aid wdt:P106 wd:Q49757 } UNION {?aid wdt:P106 wd:Q214917} UNION {?aid wdt:P106 wd:Q36180} UNION {?aid wdt:P106 wd:Q482980} UNION {?aid wdt:P106 wd:Q11774202} UNION {?aid wdt:P106 wd:Q1930187}
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
    mw = {} # MW API clients for languages we want to extract italicized text from
    ['en','de','fr'].each {|lang| mw[lang] = MediawikiApi::Client.new("https://#{lang}.wikipedia.org/w/api.php") }

    puts "coming up with some guesses..."
    a = Author.where(status: NONE).limit(max)
    return if a.nil?
    a.each {|auth| 
     print "attempting to guess a language for Q#{auth.qid}..."
     guess = guess_lang(auth)
     if guess.empty?
       auth.status = NO_GUESS
     else
       auth.guess = guess[:guess]
       italics = italics_from_article(auth.qid, mw, auth.guess)
       auth.heuristic = guess[:heuristic]
       auth.status = READY_FOR_HUMAN
       auth.other_qid = guess[:other_qid]
       auth.bucket = rand(200)
       auth.italics = italics
     end
     auth.save!
    }
  end

  def guess_lang(author)
    ret = {}
    # heuristics
    item = Wikidata::Item.find("Q#{author.qid}")
    return ret if item.nil?
    # by language of associated work?
    works = item.properties("P800") # notable works
    if works.count > 0 and not (works.first.nil?)
      worklangs = works.first.properties('P364') # original language
      if worklangs.count > 0
        return {heuristic: NOTABLE_WORK, guess: worklangs.first.id[1..-1].to_i, other_qid: works.first.id[1..-1].to_i} # offer language of notable work as a guess
      end
    end
    # by country?
    countries = item.properties("P27")
    if countries.count == 1 and not (countries.first.nil?)
      country = countries.first

      # exceptions
      return ret if [Q_BELGIUM, Q_INDIA].include? country.id[1..-1].to_i # Make no assumptions about India, and don't mess with Belgian language politics :)
      off_langs = country.properties("P37")
      if off_langs.count > 0
        unless off_langs.first.nil?
          return {heuristic: CITIZENSHIP, guess: off_langs.first.id[1..-1].to_i, other_qid: country.id[1..-1].to_i} # offer first official language as a guess
        end
      else
        if country.id[1..-1].to_i == Q_USA
          # The US doesn't have an official language, but it's still practical t offer a guess of English.
          return {heuristic: CITIZENSHIP, guess: Q_ENGLISH, other_qid: Q_USA}
        end
      end
    end # TODO: anything intelligent we can guess if more than one country listed? 
    #  
    return ret
  end
  def assign_tile
    a = Author.where(status: READY_FOR_HUMAN).order(bucket: :asc).first
    return nil if a.nil?
    a.status = ASSIGNED
    a.save!
    return a
  end
  def label_for_guess(tile, lang) 
    item = Wikidata::Item.find("Q#{tile.guess}")
    return 'ERROR' if item.nil?
    return item.labels[lang].value
  end
  def reason_for_guess(tile, lang)
    item = Wikidata::Item.find("Q#{tile.other_qid}")
    return 'ERROR' if item.nil?
    lbl = item.labels[lang].value
    lbl = item.labels['en'].value if lbl.nil? # fall back to English if no label requested lang
    lbl = item.labels.first if lbl.nil? # fall back to any label if no English
    case tile.heuristic 
    when CITIZENSHIP
      return "it is spoken in #{lbl}"
    when NOTABLE_WORK
      return "s/he is the author of #{lbl}, which is originally in this language."
    else
      return 'ERROR'
    end
  end
  def italics_from_article(qid, mw, guessed_lang)
    # heuristic: if guessed lang is French or German, hit up those Wikipedias for italics (possible names of works), otherwise default to English
    # NOTE: not sure whether work names are italicized in other languages. TODO
    print " grabbing italics... "
    item = Wikidata::Item.find("Q#{tile.guess}")
    site = case guessed_lang
      when Q_GERMAN
        'de'
      when Q_FRENCH
        'fr'
      else
        'en'
      end
    sitelinks = item.sitelinks
    return nil if sitelinks.nil?
    sitelink = sitelinks[site+'wiki']
    if sitelink.nil? and site != 'en'
      site = 'en' # fallback
      sitelink = sitelinks[site+'wiki'] # and try again
    end
    return nil if sitelink.nil?
    title = sitelink.title
    src = mw[site].get_wikitext(title).body # grab wikitext
    stripped = src.gsub('[[','').gsub(']]','').gsub("'''",'')
    italics = stripped.scan(/''.*?''/).map {|match| match[2..-3] } # grab expressions in italics, stripping the single quotes
    return italics.join("\n")
  end
  def get_tiles(numparam, lang)
    num = numparam.to_i || 1
    ret = []
    (1..num).each do |i|
      tile = assign_tile
      unless tile.nil?
        lbl = label_for_guess(tile, lang)
        reason = reason_for_guess(tile, lang)
        italics = tile.italics # sub needed?
        text = "#{lbl} because #{reason}"
        text += "\n\nThe following italicized text appears in the Wikipedia article:\n" + italics unless italics.nil?
        ret << {id: tile.id, sections: [{type: 'item', q: "Q#{tile.qid}"}, {type: 'text', text: text}], controls: 
          [{type: 'buttons', 
          entries: 
            [{type: 'green', decision: 'yes', label: lbl, api_action: 
              {action: 'wbcreateclaim', entity: "Q#{tile.qid}", property: 'P1412', snaktype: 'value', value: '{"entity-type":"item", "numeric-id":'+tile.guess.to_s+'}' }},
          {type: 'white', decision: 'skip', label: 'not sure'}, {type: 'blue', decision: 'no', label: 'No'} ]}]}
      end
    end
    return ret
  end
end
