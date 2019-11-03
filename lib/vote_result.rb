# howvoted.rb

require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'optparse'

class VoteResult
  attr_accessor :date
  attr_accessor :number
  attr_accessor :legisnum
  attr_accessor :question 
  attr_accessor :descr
  attr_accessor :vote
  attr_accessor :legislator
  
  @@cache_dir = File.join(ENV["HOME"], ".cache", "howvoted")
  @@host = "clerk.house.gov"
  @@path_template = "/evs/%d/roll%03d.xml"

  def self.cache_dir; return @@cache_dir; end
  def self.cache_dir=(dir); @@cache_dir = dir; end

  def self.host; return @@host; end
  def self.host=(host); @@host = host; end

  def self.path_template; return @@path_template; end
  def self.path_template=(template); @@path_template = template; end

  def initialize(**kwargs)
    name_id = kwargs[:name_id]
    number = kwargs[:number]
    year = kwargs[:year] || Time.now.year

    doc = Nokogiri.XML(get(year, number))
    @date = doc.css("rollcall-vote vote-metadata action-date")[0].content
    @number = doc.css("rollcall-vote vote-metadata rollcall-num")[0].content.to_i
    @legisnum = doc.css("rollcall-vote vote-metadata legis-num")[0]&.content
    @question = doc.css("rollcall-vote vote-metadata vote-question")[0].content
    @descr = doc.css("rollcall-vote vote-metadata vote-desc")[0].content
    @legislator = name_id

    # XXX probably should use xpath instead
    doc.css("rollcall-vote vote-data recorded-vote").detect { |node|
      if node.children.detect { |x| x.name == "legislator" && x["name-id"] == @legislator }
        @vote = node.children.detect { |x| x.name == "vote" }.content
      end
    }
  end

  def pretty
    s = "#{@date} (#{@number.to_s}) #{@legisnum.inspect}\t#{@question}\t-- #{@vote}\n"
    s += "#{descr}"
    return s
  end

  private def get(year, number)
    dir = File.join(@@cache_dir, year.to_s)
    FileUtils.mkdir_p(dir) if not File.directory?(dir)
    path = sprintf(@@path_template, year, number)
    cached_doc = File.join(@@cache_dir, year.to_s, File.basename(path))
  
    # XXX should check for 200 OK
    if not File.file?(cached_doc)
      content = Net::HTTP.get(@@host, path)
      File.open(cached_doc, "w") { |f| f.puts(content) } if content
    end
  
    return File.read(cached_doc)
  end
end

if $0 == __FILE__
  @name_id = nil
  @year = Time.now.year
  @n_roll_calls = 100
  @custom_cache_dir = nil
  
  parser = OptionParser.new do |opts|
    opts.on("--cache-dir PATH") { |dir| @custom_cache_dir = File.expand_path(dir) }
    opts.on("--name-id ID") { |id| @name_id = id }
    opts.on("--limit N") { |n| @n_roll_calls = n.to_i }
    opts.on("--year YEAR") { |y| @year = y.to_i }
  end
  parser.parse!(ARGV)

  VoteResult.cache_dir = @custom_cache_dir if @custom_cache_dir
  
  (1..@n_roll_calls).each do |i|
    vr = VoteResult.new(:name_id => @name_id, :number => i, :year => @year)
    puts vr.inspect
  end
end
