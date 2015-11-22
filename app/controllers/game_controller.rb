require 'authorlang'
include Authorlang

class GameController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def desc
    resp = {label: {en: "AuthorLang game"}, description: {en: "populate the P1412 property by guessing from notable works or citizenship"}, icon: ''}
    render :json => resp.to_json, :callback => params['callback']
  end

  def tiles
    @tiles = get_tiles(params['num'])
    resp = {tiles: @tiles}
    render :json => resp.to_json, :callback => params['callback']
  end

  def log_action
    a = Author.find(params['tile'].to_i)
    unless a.nil?
      a.status = DONE
      a.decision = params['decision'] == 'yes' ? YES : NO
      a.username = params['username']
      a.save!
    end
    render nothing: true
  end
  def main
    # the distributed Wikidata Game API uses the reserved 'action' parameter, so we need to grab it from the raw query string
    request.query_string =~ /action=([a-z]*)/
    q = $1
    case q
    when 'desc'
      desc
    when 'tiles'
      tiles
    when 'log_action'
      log_action
    else
      render body: "params = #{params.to_s}"
      #render nothing: true
    end
  end
end
