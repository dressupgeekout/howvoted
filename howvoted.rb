require 'erb'
require 'rack'
require 'sinatra'
require 'pstore'

$LOAD_PATH.unshift(File.join(__dir__, "lib"))
require 'vote_result'
require 'legislator'

legislators = {}

(2017..Time.now.year).each do |year|
  legislators[year] = PStore.new(sprintf(Legislator::STORE_PATH_TEMPLATE, year))
end

LEGISLATORS = legislators
CONSTITUTION_RATIFICATION_YEAR = 1787

helpers do
  def h(str)
    return Rack::Utils.escape_html(str)
  end

  def year 
    return (params["year"] && params["year"].to_i) || Time.now.year
  end

  def ord(n)
    case n % 10
    when 0
      return "eth"
    when 1
      return "st"
    when 2
      return "nd"
    when 3
      return "rd"
    else 
      return "th"
    end
  end

  def year_to_congress
    y = year - CONSTITUTION_RATIFICATION_YEAR
    n = y / 2
    session = (y % 2) + 1
    return [n.to_s+ord(n), session.to_s+ord(session)]
  end

  def params_with_changed_year(new_year)
    new_params = {}

    params.each do |k, v|
      if k == "year"
        new_params[k] = new_year
      else
        new_params[k] = v
      end
    end

    new_params["year"] = new_year if not new_params["year"]

    return new_params
  end
end

get '/' do
  store = LEGISLATORS[year]

  erb :legislators, :layout => :layout_default, :locals => {
    :congress => year_to_congress,
    :legislators => store.transaction { store["__ALL__"] }, 
  }
end

get '/record' do
  vrs = []
  name_id = params["name_id"] # XXX or 404

  (1..500).each do |n|
    vrs << VoteResult.new(:name_id => name_id, :year => year, :number => n)
  end

  store = LEGISLATORS[year]
  
  erb :index, :layout => :layout_default, :locals => {
    :congress => year_to_congress,
    :results => vrs,
    :legislator => store.transaction { store[name_id] },
  }
end
