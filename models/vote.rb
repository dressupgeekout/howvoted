require_relative 'roll_call'
require_relative 'legislator'

class Vote < Sequel::Model(:votes)
  def roll_call
    return RollCall[self.roll_call_id]
  end

  def legislator
    return Legislator[self.legislator_id]
  end
end
