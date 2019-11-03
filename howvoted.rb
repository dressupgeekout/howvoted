require 'erb'
require 'rack'
require 'sinatra'
require 'sequel'

########## ########## ########## ##########

DB = Sequel.connect(ENV["DB_URI"])
$LOAD_PATH.unshift(File.join(__dir__, "models"))
require 'legislator'
require 'roll_call'
require 'vote'

########## ########## ########## ##########

CONSTITUTION_RATIFICATION_YEAR = 1787

########## ########## ########## ##########

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

########## ########## ########## ##########

get '/' do
  erb :legislators, :layout => :layout_default, :locals => {
    :congress => year_to_congress,
    :legislators => Legislator.where(:year => year).all,
  }
end

get '/record/?' do
  name_id = params["name_id"] # XXX or 400

  legislator = Legislator.where(:year => year, :name_id => name_id).first

  erb :index, :layout => :layout_default, :locals => {
    :congress => year_to_congress,
    :votes => Vote.where(:legislator_id => legislator.id).all.sort_by { |v| v.roll_call.number },
    :legislator => legislator,
  }
end

get '/compare/?' do
  name_id1 = params["name_id1"] # XXX or 400
  name_id2 = params["name_id2"] # XXX or 400

  legislator1 = Legislator.where(:year => year, :name_id => name_id1).first
  legislator2 = Legislator.where(:year => year, :name_id => name_id2).first

  erb(:compare, :layout => :layout_default, :locals => {
    :legislator1 => legislator1,
    :legislator2 => legislator2,
    :legislator1_results => Vote.where(:legislator_id => legislator1.id).all.sort_by { |v| v.roll_call.number },
    :legislator2_results => Vote.where(:legislator_id => legislator2.id).all.sort_by { |v| v.roll_call.number },
    :congress => year_to_congress,
  })
end
