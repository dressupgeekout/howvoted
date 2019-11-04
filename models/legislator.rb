class Legislator < Sequel::Model(:legislators)
  def pretty
    return "#{self.full_name} (#{self.party}-#{self.state})"
  end

  def portrait_url
    return "http://bioguide.congress.gov/bioguide/photo/#{self.name_id[0]}/#{self.name_id}.jpg"
  end

  def portrait_img
    return %Q(<img alt="" src="#{self.portrait_url}" height="225"/>)
  end

  def senator?
    return self.senator
  end
end
