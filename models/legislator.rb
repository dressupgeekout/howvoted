class Legislator < Sequel::Model(:legislators)
  def pretty
    return "#{@name} (#{@party}-#{@state})"
  end
end
