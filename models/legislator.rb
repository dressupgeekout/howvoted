class Legislator < Sequel::Model(:legislators)
  def pretty
    return "#{self.full_name} (#{self.party}-#{self.state})"
  end
end
