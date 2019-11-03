require 'nokogiri'
require 'sequel'

if not File.file?("member-bioguide-ids.html")
  system %Q(curl -L -o member-bioguide-ids.html https://www.congress.gov/help/field-values/member-bioguide-ids)
end

Sequel.connect(ENV["DB_URI"])
$LOAD_PATH.unshift(File.join(__dir__, "..", "models"))
require 'legislator'

doc = Nokogiri::HTML(File.read("member-bioguide-ids.html"))

table_rows = doc.css("table tr")

table_rows.each do |row|
  name_e, name_id_e = row.css("td")
  next if not (name_e and name_id_e)
  name = name_e.children[0].content
  name_id = name_id_e.children[0].content

  name_bit = name.split(" (")[0]

  name_bits = name_bit.split(", ")

  full_name = [name_bits[1], name_bits[0], name_bits[2]||""].join(" ").strip

  p Legislator.where(:name_id => name_id).update(:full_name => full_name)
end
