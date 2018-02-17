require_relative 'person'
# An Occupant is a Person in a building on a floor.
# An Occupant will request elevator services either from a Floor wait queue (with call buttons) or within an elevator (with floor buttons).
# The Simulator will place an Occupant on na Floor and will provide the occupant with a destination and a wait queue arrival time.
# The success of an elevator algorithm will mostly depend on the user experience statistics gathered here.
class Occupant < Person
  LOGGER_MODULE  = 'Occupant'

  attr_reader :destination, :enq_time, :max_trip_time, :max_wait_time, :total_trip_time, :total_wait_time, :trips

  # attr_reader :completed_trips, :destination, :weight

  # A trip starts when an occupant arrives at an elevator lobby (is moved from a floor's occupant list to a floor's waitlist).
  # A ride begins when an occupant enters an elevator (is moved from a floor's waitlist to an elevator's rider list).
  # A ride and a trip both end when an occupant is discharged from an elevator (moved from an elevator's rider list to a floor's occupant list).

  def initialize(id, weight)
    super(id, weight)
    @destination = 0    # the floor an occupant wishes to travel to.
    @enq         = false # this occupant is waiting to enq at enq_time. To keep simulator from re-enqing once enq'd.
    @enq_time    = 0.0  # the time at which an occupant will arrive at an elevator lobby in order to proceed to destination.
    init_stats
    Logger::msg(Simulator::time, LOGGER_MODULE, id, Logger::DEBUG, 'created')
  end

  # Trip statistics
  def init_stats
    @trips              = 0
    @total_ride_time    = 0.0
    @total_trip_time    = 0.0
    @total_wait_time    = 0.0
    @max_ride_time      = 0.0
    @max_trip_time      = 0.0
    @max_wait_time      = 0.0
    # Interim calculations
    @on_waitlist_time   = 0.0
    @on_elevator_time   = 0.0
  end

  # Setup trip data.
  def enq(destination, time)
    @destination = destination
    @enq_time = time
    @enq = true
  end

  # Boarding elevator. Calculate wait time.
  def on_elevator(on_elevator_time)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "on elevator")
    @enq = false
    @on_elevator_time = on_elevator_time
    wait_time = on_elevator_time - @on_waitlist_time
    @total_wait_time += wait_time
    @max_wait_time = [wait_time, @max_wait_time].max
  end

  # End trip. Calculate trip time.
  def on_floor(on_floor_time)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "on floor")
    ride_time = on_floor_time - @on_elevator_time
    @total_ride_time += ride_time
    @max_ride_time = [ride_time, @max_ride_time].max
    trip_time = on_floor_time - @on_waitlist_time
    @total_trip_time += trip_time
    @max_trip_time = [trip_time, @max_trip_time].max
    @trips += 1
  end

  # Begin trip.
  def on_waitlist(on_waitlist_time)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "on waitlist")
    @on_waitlist_time = on_waitlist_time
  end

  def time_to_board?
    @enq && @enq_time <= Simulator::time
  end
end
