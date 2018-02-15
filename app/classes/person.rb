# A Human Being.
# For this app, a Person needs weight only.
class Person
  attr_reader :id, :weight
  def initialize(id, weight)
    @id = id
    @weight = weight
  end
end
