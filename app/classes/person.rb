# A Person can use an elevator.
class Person
  STATIC_SEED = 101
  attr_reader :destination, :weight

  def initialize(id, initial_destination)
    @id          = id
    @destination = initial_destination
# TODO switch to normal distribution of weight. 170 +/ 29
    @weight      = Simulation::rng.rand(200..241)
  end
end
