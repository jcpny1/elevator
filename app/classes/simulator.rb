@id# The Elevator operation simulator.
# The Simulator mimics user interaction with the elevators.
class Simulator
  LOGGER_MODULE      = 'Simulator'  # for console logger.

  LOOP_DELAY      = 0.01 # (seconds) - sleep delay in simulation loop.
  LOOP_TIME_INCR  = 1.0  # (seconds) - amount of time to advance simulated time for each simulation loop.
  RNG_SEED        = 101  # for random number generation. Using a static seed value for repeatable simulation runs.

  @@rng       = nil   # Random number generator.
  @@sim_time  = nil   # Simulated time (in seconds).

  def initialize(name, logic, modifiers, num_floors, num_elevators, num_occupants, debug_level)
    @id             = 0    # for console logger.
    @name           = name
    @logic          = logic
    @modifiers      = modifiers
    @num_floors     = num_floors
    @num_elevators  = num_elevators
    @num_occupants  = num_occupants
    @debug_level    = debug_level
    @@rng = Random.new(RNG_SEED)

    @@sim_time = 0.0
    Logger::init('*', @debug_level)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, 'starting')

    @floors     = create_floors(@num_floors)
    @elevators  = create_elevators(@num_elevators, @floors, @modifiers)
    @controller = create_controller(@elevators, @floors, @logic)
    @occupants  = create_occupants(@num_occupants)
  end

  def self.load_passenger(passenger, floor)
    passenger.on_elevator(Simulator::time)
    floor.leave_waitlist(passenger)
  end

  def self.rng
    @@rng
  end

  def run
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, 'Morning Rush begin')
    queue_morning_occupants
    run_sym
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, 'Morning Rush end')
    output_stats
    clear_stats
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, 'Evening Rush begin')
    queue_evening_occupants
    run_sym
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, 'Evening Rush end')
    output_stats
    # cleanup
  end

  def self.unload_passenger(passenger, floor)
    passenger.on_floor(Simulator::time)
    floor.accept_occupant(passenger)
  end

private

  # Reset statistics between scenarios.
  def clear_stats
    @occupants.each { |occupant| occupant.init_stats }
    @elevators.each { |elevator| elevator[:car].init_stats }
  end

  # Create controller.
  def create_controller(elevators, floors, logic)
    q = Queue.new
    c = Controller.new(q, elevators, floors.length, logic)
    t = Thread.new { c.run }
    controller = {queue: q, thread: t, controller: controller}
    @floors.each { |floor| floor.controller_q = q }
  end

  # Create elevators.
  def create_elevators(elevator_count, floors, modifiers)
    elevators = []
    elevator_count.times do |i|
      elevator_queue  = Queue.new
      elevator_car = Elevator.new(i, elevator_queue, floors)
      elevator_thread = Thread.new { elevator_car.run }
      elevators << {id: i, thread: elevator_thread, car: elevator_car}
    end
    elevators
  end

  # Create floors and place all building occupants on first floor.
  def create_floors(floor_count)
    floors = []
    (floor_count+1).times { |i| floors << Floor.new(i) }
    floors
  end

  # Create occupants.
  def create_occupants(occupant_count)
    occupants = []
    occupant_count.times { |i| occupants << Occupant.new(i, Simulator::rng.rand(170..200)) }  # TODO eventually switch to normal distribution of weight. 170 +/- 29
    occupants
  end

  def output_stats
    total_trips = 0
    total_trip_time = 0.0
    total_wait_time = 0.0
    max_trip_time   = 0.0
    max_wait_time   = 0.0
    @occupants.each do |occupant|
      total_trips += occupant.trips
      total_wait_time += occupant.total_wait_time
      total_trip_time += occupant.total_trip_time
      max_trip_time   = occupant.max_trip_time if occupant.max_trip_time > max_trip_time
      max_wait_time   = occupant.max_wait_time if occupant.max_wait_time > max_wait_time
    end
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Name         : #{@name}")
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Logic        : #{@logic}")
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Run Time     : %5.1f" % Simulator::time)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Total Trips  : %5.1f" % total_trips)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Avg Wait Time: %5.1f" % (total_wait_time/total_trips))
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Avg Trip Time: %5.1f" % (total_trip_time/total_trips))
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Max Wait Time: %5.1f" % max_wait_time)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Max Trip Time: %5.1f" % max_trip_time)

    total_distance = 0
    @elevators.each do |elevator|
      distance = elevator[:car].elevator_status[:distance]
      total_distance += distance
    end
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "  Elevator dx  : %5.1f" % total_distance)
    @elevators.each do |elevator|
      distance = elevator[:car].elevator_status[:distance]
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "    Elevator #{elevator[:id]} : %5.1f" % distance)
    end
  end

  # Place all occupants on their floor's waitlist at random times with destination = first floor.
  def queue_evening_occupants
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "queue_evening_occupants")
    @occupants.each do |occupant|
      arrival_time = @@rng.rand(Simulator::time..Simulator::time+600)  # TODO do a normal distribution of arrival time around 5pm +/- 15
      current_floor = occupant.destination
      occupant.enq(Floor::GROUND_FLOOR, arrival_time)
      # @floors[current_floor].enter_waitlist(occupant)
    end
  end

  # Place all occupants on first floor waitlist at random times.
  def queue_morning_occupants
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "queue_morning_occupants")
    @occupants.each do |occupant|
      destination_floor = @@rng.rand(2..@num_floors-1)
      arrival_time = @@rng.rand(0..600)  # TODO do a normal distribution of arrival time around 9am +/- 15
      @floors[Floor::GROUND_FLOOR].accept_occupant(occupant)
      occupant.enq(destination_floor, arrival_time)
    end
  end

  def run_sym
    # Scenario is complete when there are no more waiters and no more riders.
    while 1
      any_waiters = update_wait_queues
      any_riders = @elevators.any? { |elevator| !elevator[:car].elevator_status[:riders][:occupants].length.zero? }
      any_future_waiters = @occupants.any? { |occupant| occupant.enq_time >= Simulator::time }
      break if !(any_waiters || any_riders || any_future_waiters)
      sleep LOOP_DELAY
      @@sim_time += LOOP_TIME_INCR
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG_3, 'time check')
    end
  end

  def self.time
    @@sim_time
  end

  # Move floor occupants to wait queue as needed.
  # Return true if any waiters, false otherwise.
  def update_wait_queues
    any_waiters ||= false
    @floors.each do |floor|
      floor.occupants.each { |occupant| floor.enter_waitlist(occupant) if occupant.time_to_board? }
      any_waiters ||= !floor.waitlist.length.zero?
    end
    any_waiters
  end




# Shutdown elevators and controller.
def cleanup
  @controller[:queue] << {time: Simulator::time, cmd: 'END'}

  # Keep clock running while waiting for elevators threads to complete.
  while @elevators.reduce(false) { |status, elevator| status || elevator[:thread].status }
    sleep LOOP_DELAY
    @@sim_time += LOOP_TIME
  end

  # Clean up controller.
  @controller[:thread].join()
  @controller[:queue].close

  # Clean up elevators.
  @elevators.each do |elevator|
    elevator[:thread].join()
    elevator[:queue].close
  end
end
end
