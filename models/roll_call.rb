class RollCall < Sequel::Model(:roll_calls)
  # XXX copypasta from the app
  CONSTITUTION_RATIFICATION_YEAR = 1787

  FLAVORS = {
    :BILL => 1,
    :RESOLUTION => 2,
  }

  # XXX copypasta from the app
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

  # XXX copypasta from the app
  def year_to_congress
    y = self.year - CONSTITUTION_RATIFICATION_YEAR
    n = y / 2
    session = (y % 2) + 1
    return [n.to_s+ord(n), session.to_s+ord(session)]
  end

  def flavor
    return case self.legisnum
    when /^H\ R\ /
      FLAVORS[:BILL]
    when /^H\ RES\ /
      FLAVORS[:RESOLUTION]
    else
      nil
    end
  end

  def bill_link
    case flavor
    when FLAVORS[:BILL]
      dirname = "house-bill"
    when FLAVORS[:RESOLUTION]
      dirname = "house-resolution"
    else
      return nil
    end
    nth, _ = self.year_to_congress
    billno = self.legisnum.split(/\s+/).last
    return "https://www.congress.gov/bill/#{nth}-congress/#{dirname}/#{billno}"
  end
end
