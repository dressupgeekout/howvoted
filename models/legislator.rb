class Legislator < Sequel::Model(:legislators)
  def pretty
    return "#{self.name} (#{self.party}-#{self.state})"
  end
end
