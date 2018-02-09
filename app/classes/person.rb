# A Person can use an elevator.
class Person
  attr_reader :destination, :weight

  def initialize(id, initial_destination)
    @id          = id
    @destination = initial_destination
    @weight      = 170
  end
end
