require 'net/http'
require 'nokogiri'
require 'pstore'

require_relative 'vote_result'

class Legislator
  STORE_PATH_TEMPLATE = File.join(VoteResult.cache_dir, "%d", "legislators.pstore")
  attr_accessor :name_id
  attr_accessor :sort_field
  attr_accessor :unaccented_name
  attr_accessor :party
  attr_accessor :state
  attr_accessor :role
  attr_accessor :name

  def pretty
    return "#{@name} (#{@party}-#{@state})"
  end
end

if $0 == __FILE__
  from_year = ARGV.shift.to_i || Time.now.year

  (from_year..Time.now.year).each do |year|
    store = PStore.new(sprintf(Legislator::STORE_PATH_TEMPLATE, year))
    store.transaction { store["__ALL__"] = [] }

    # The first "vote" is actually a roll-call
    doc = Nokogiri.XML(File.read(File.join(VoteResult.cache_dir, year.to_s, "roll001.xml")))

    store.transaction do
      doc.css("rollcall-vote vote-data recorded-vote legislator").each do |node|
        l = Legislator.new
        l.name_id = node["name-id"]
        l.sort_field = node["sort-field"]
        l.unaccented_name = node["unaccented-name"]
        l.party = node["party"]
        l.state = node["state"]
        l.role = node["role"]
        l.name = node.content
        $stderr.puts("+ (#{year}) #{l.name} #{l.party}-#{l.state}")
        store[l.name_id] = l
        store["__ALL__"] << l
      end
    end
  end
end
