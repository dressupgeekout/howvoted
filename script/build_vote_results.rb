require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'optparse'
require 'sequel'

CACHE_DIR = File.join(ENV["HOME"], ".cache", "howvoted").freeze
HOST = "clerk.house.gov".freeze
PATH_TEMPLATE = "/evs/%d/roll%03d.xml".freeze

SENATE_CACHE_DIR = File.join(ENV["HOME"], ".cache", "howvoted", "senate").freeze
SENATE_HOST = "www.senate.gov".freeze
SENATE_PATH_TEMPLATE = "/legislative/LIS/roll_call_votes/vote%d%d/vote_%d_%d_%05d.xml".freeze

########## ########## ########## ##########

CONSTITUTION_RATIFICATION_YEAR = 1787

# XXX mostly copypasta from howvoted.rb
def year_to_congress(year)
  y = year - CONSTITUTION_RATIFICATION_YEAR
  n = y / 2
  session = (y % 2) + 1
  return [n, session]
end

# Fetch the XML file from the internet, or refer to the local cache if
# it's already been fetched.
def get(year, number)
  dir = File.join(CACHE_DIR, year.to_s)
  FileUtils.mkdir_p(dir) if not File.directory?(dir)
  path = sprintf(PATH_TEMPLATE, year, number)
  cached_doc = File.join(CACHE_DIR, year.to_s, File.basename(path))

  # XXX should check for 200 OK
  if not File.file?(cached_doc)
    content = Net::HTTP.get(HOST, path)
    File.open(cached_doc, "w") { |f| f.puts(content) } if content
  end

  return File.read(cached_doc)
end

def senate_get(year, number)
  dir = File.join(SENATE_CACHE_DIR, year.to_s)
  FileUtils.mkdir_p(dir) if not File.directory?(dir)
  nth, session = year_to_congress(year)
  path = sprintf(SENATE_PATH_TEMPLATE, nth, session, nth, session, number)
  cached_doc = File.join(SENATE_CACHE_DIR, year.to_s, File.basename(path))

  # XXX should check for 200 OK
  if not File.file?(cached_doc)
    content = Net::HTTP.get(URI("https://#{SENATE_HOST}#{path}"))
    File.open(cached_doc, "w") { |f| f.puts(content) } if content
  end

  return File.read(cached_doc)
end

########## ########## ########## ##########

@year = Time.now.year
@n_roll_calls = 100
@n_roll_calls_senate = 100
@db_uri = nil

parser = OptionParser.new do |opts|
  opts.on("--limit N") { |n| @n_roll_calls = n.to_i }
  opts.on("--senate-limit N") { |n| @n_roll_calls_senate = n.to_i }
  opts.on("--year YEAR") { |y| @year = y.to_i }
  opts.on("--db URI") { |uri| @db_uri = uri }
end
parser.parse!(ARGV)

DB = Sequel.connect(@db_uri)

$LOAD_PATH.unshift(File.join(__dir__, "..", "models"))
require 'legislator'
require 'roll_call'
require 'vote'

# Obtain the mapping of name_id->fullname.
if not File.file?("member-bioguide-ids.html")
  system %Q(curl -L -o member-bioguide-ids.html https://www.congress.gov/help/field-values/member-bioguide-ids)
end

full_names = {}
full_names_doc = Nokogiri::HTML(File.read("member-bioguide-ids.html"))

full_names_doc.css("table tr").each do |row|
  name_e, name_id_e = row.css("td")
  next if not (name_e and name_id_e)
  name = name_e.children[0].content
  name_id = name_id_e.children[0].content
  name_part = name.split(" (")[0]
  name_bits = name_part.split(", ")
  full_name = [name_bits[1], name_bits[0], name_bits[2]||""].join(" ").strip
  full_names[name_id] = full_name
end

# The first "vote" is actually a roll-call. Instantiate all of the house
# reps based on that.
doc = Nokogiri.XML(get(@year, 1))

DB.transaction do
  doc.css("rollcall-vote vote-data recorded-vote legislator").each do |node|
    name_id = node["name-id"]

    if Legislator.where(:name_id => name_id, :year => @year, :senator => false).any?
      next
    end

    l = Legislator.new
    l.name_id = name_id
    l.sort_field = node["sort-field"]
    l.unaccented_name = node["unaccented-name"]
    l.party = node["party"]
    l.state = node["state"]
    l.role = node["role"]
    l.name = node.content
    l.full_name = full_names[name_id]
    l.year = @year
    l.senator = false
    l.save
    p l
  end
end

# OK now let's do the senators.
doc = Nokogiri.XML(senate_get(@year, 1))

DB.transaction do
  doc.css("roll_call_vote members member").each do |node|
    name_id = node.at_css("lis_member_id").content
    first_name = node.at_css("first_name").content
    last_name = node.at_css("last_name").content

    if Legislator.where(:name_id => name_id, :year => @year, :senator => true).any?
      next
    end

    l = Legislator.new
    l.name_id = name_id
    l.senator = true
    l.year = @year
    l.party = node.at_css("party").content
    l.state = node.at_css("state").content
    l.name = last_name
    l.full_name = first_name + " " + last_name
    l.save
    p l
  end
end

all_reps = Legislator.select(:id, :name_id).where(:year => @year, :senator => false)
all_senators = Legislator.select(:id, :name_id).where(:year => @year, :senator => true)

# OK, plugging in all the individual votes. Where should we start?
start = -1
(1..@n_roll_calls).each do |i|
  if not RollCall.where(:number => i, :year => @year).any?
    start = i
    break
  end
end

# Didn't set the start? That means we're all done!
exit if start == -1

(start..@n_roll_calls).each do |i|
  DB.transaction do
    doc = Nokogiri.XML(get(@year, i))

    r = RollCall.new
    r.senate = false
    r.date = doc.at_css("rollcall-vote vote-metadata action-date").content
    r.number = i
    r.legisnum = doc.at_css("rollcall-vote vote-metadata legis-num")&.content
    r.question = doc.at_css("rollcall-vote vote-metadata vote-question").content
    r.descr = doc.at_css("rollcall-vote vote-metadata vote-desc").content
    r.year = @year
    r.save
    p r

    all_reps.each do |legislator|
      vote = nil # SCOPE

      # XXX probably should use xpath instead
      doc.css("rollcall-vote vote-data recorded-vote").detect { |node|
        if node.children.detect { |x| x.name == "legislator" && x["name-id"] == legislator.name_id }
          vote = node.children.detect { |x| x.name == "vote" }.content
        end
      }

      Vote.create(
        :roll_call_id => r.id,
        :legislator_id => legislator.id,
        :vote => vote
      )
    end
  end
end

(start..@n_roll_calls_senate).each do |i|
  DB.transaction do
    doc = Nokogiri.XML(senate_get(@year, i))

    r = RollCall.new
    r.senate = true
    r.date = doc.at_css("roll_call_vote vote_date").content
    r.number = i
    r.legisnum = doc.at_css("roll_call_vote document document_name").content
    r.question = doc.at_css("roll_call_vote question").content
    r.descr = doc.at_css("roll_call_vote vote_document_text").content
    r.year = @year
    r.save
    p r

    all_senators.each do |legislator|
      vote = nil # SCOPE

      # XXX probably should use xpath instead
      doc.css("roll_call_vote members member").detect { |node|
        if node.at_css("lis_member_id").content == legislator.name_id
          vote = node.at_css("vote_cast").content
        end
      }

      Vote.create(
        :roll_call_id => r.id,
        :legislator_id => legislator.id,
        :vote => vote
      )
    end
  end
end
