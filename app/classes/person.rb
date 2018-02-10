# A Person can use an elevator.
class Person
  attr_reader :completed_trips, :destination, :max_trip_time, :max_wait_time, :total_trip_time, :total_wait_time, :weight
  def initialize(id)
    @id = id
    @weight            = Simulation::rng.rand(170..200)  # TODO switch to normal distribution of weight. 170 +/- 29
    @destination       = 0
    @total_trip_time   = 0.0
    @total_wait_time   = 0.0
    @max_trip_time     = 0.0
    @max_wait_time     = 0.0
    @completed_trips   = 0
    @on_waitlist_time  = 0.0
    @on_elevator_time  = 0.0
    @off_elevator_time = 0.0
  end

  # Trips: A trip starts on origin floor waitlist, and ends on discharge to destination floor.

  def on_elevator(time)
    @on_elevator_time = time
    wait_time = @on_elevator_time - @on_waitlist_time
    @total_wait_time += wait_time
    @max_wait_time = wait_time if wait_time > @max_wait_time
  end

  def on_floor(time)
    @on_floor_time = time
    trip_time = @on_floor_time - @on_waitlist_time
    @total_trip_time += trip_time
    @max_trip_time = trip_time if trip_time > @max_trip_time
    @completed_trips += 1
  end

  def on_waitlist(time, destination)
    @on_waitlist_time = time
    @destination = destination
  end
end
