require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'optparse'
require 'sequel'

CACHE_DIR = File.join(ENV["HOME"], ".cache", "howvoted").freeze
HOST = "clerk.house.gov".freeze
PATH_TEMPLATE = "/evs/%d/roll%03d.xml".freeze

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

@year = Time.now.year
@n_roll_calls = 100
@db_uri = nil

parser = OptionParser.new do |opts|
  opts.on("--limit N") { |n| @n_roll_calls = n.to_i }
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

# The first "vote" is actually a roll-call. Instantiate all of the
# legislators based on that.
doc = Nokogiri.XML(get(@year, 1))

DB.transaction do
  doc.css("rollcall-vote vote-data recorded-vote legislator").each do |node|
    name_id = node["name-id"]

    if Legislator.where(:name_id => name_id, :year => @year).any?
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
    l.save
    p l
  end
end

all_legislators = Legislator.select(:id, :name_id).where(:year => @year)

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
    r.date = doc.at_css("rollcall-vote vote-metadata action-date").content
    r.number = i
    r.legisnum = doc.at_css("rollcall-vote vote-metadata legis-num")&.content
    r.question = doc.at_css("rollcall-vote vote-metadata vote-question").content
    r.descr = doc.at_css("rollcall-vote vote-metadata vote-desc").content
    r.year = @year
    r.save
    p r

    all_legislators.each do |legislator|
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
