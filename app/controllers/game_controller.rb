class GameController < ApplicationController
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
    render :nothing
  end
end
