# The Elevator operation simulator.
# The Simulator mimics user interaction with the elevators.
class Simulator
  LOGGER_MODULE      = 'Simulator'  # for console logger.

  MODULE_ID       = 0    # for console logger.
  LOOP_DELAY      = 0.01 # (seconds) - sleep delay in simulation loop.
  LOOP_TIME_INCR  = 1.0  # (seconds) - amount of time to advance simulated time for each simulation loop.
  RNG_SEED        = 101  # for random number generation. Using a static seed value for repeatable simulation runs.

  @@debug     = nil   # Debug enabled?
  @@rng       = nil   # Random number generator.
  @@sim_time  = nil   # Simulated time (in seconds).

  def initialize(logic:'FCFS', modifiers: {'NOPICK': true}, floors: 6, elevators: 1, occupants: 20, debug:false, debug_level: Logger::NONE)
    @id            = MODULE_ID
    @logic         = logic
    @modifiers     = modifiers
    @num_floors    = floors
    @num_elevators = elevators
    @num_occupants = occupants
    @@debug        = debug
    @debug_level   = debug_level
    @@rng = Random.new(RNG_SEED)

    @@sim_time = 0.0
    Logger::init('*', @debug_level)
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "Simulator #{@id} starting")

    @floors     = create_floors(@num_floors)
    @elevators  = create_elevators(@num_elevators, @floors, @modifiers)
    @controller = create_controller(@elevators, @num_floors, @logic)
    @occupants  = create_occupants(@num_occupants)
  end

  def self.debug
    @@debug
  end

  def self.rng
    @@rng
  end

  def run
    queue_morning_occupants
    run_sym
    output_stats
    # clear_stats
    # queue_evening_occupants
    # run_sym
    # output_stats
    # cleanup
  end

  def self.unload_passenger(passenger, floor)
    floor.accept_occupant(passenger)
    passenger.on_floor(Simulator::time)
  end

private

  # Create call events.
  def create_call_events(occupants)
    calls = []
    @floors.each do |floor|
      if !floor.waitlist.empty?
        going_down = false
        going_up = false
        floor.waitlist.each do |occupant|
          next if !occupant.time_to_board
          going_down ||= occupant.destination < floor.id
          going_up ||= occupant.destination > floor.id
          break if going_up && going_down
        end
        # TODO What happened to event?
        if going_down #&& !floor.call_down
          floor.press_call_down
          calls << {time: Simulator::time, cmd: 'CALL', floor: floor.id, direction: 'dn'}
        end
        if going_up && !floor.call_up
          floor.press_call_up
          calls << {time: Simulator::time, cmd: 'CALL', floor: floor.id, direction: 'up'}
        end
      end
    end
    calls
  end

  # Create controller.
  def create_controller(elevators, num_floors, logic)
    q = Queue.new
    c = Controller.new(q, elevators, num_floors, logic)
    t = Thread.new { c.run }
    controller = {queue: q, thread: t, controller: controller}
  end

  # Create elevators.
  def create_elevators(elevator_count, floors, modifiers)
    elevators = []
    elevator_count.times do |i|
      elevator_queue  = Queue.new
      elevator = Elevator.new(i, elevator_queue, floors)
      elevator_thread = Thread.new { elevator.run }
      elevators << { id: i, thread: elevator_thread, car: elevator }
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

  def clear_stats
    @occupants.each { |occupant| occupant.init_stats }
    @elevators.each { |elevator| elevator[:car].init_stats }
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
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, 'Simulator done.')
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Logic        : #{@logic}")
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Run Time     : %5.1f" % Simulator::time)
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Total Trips  : %5.1f" % total_trips)
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Avg Wait Time: %5.1f" % (total_wait_time/total_trips))
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Avg Trip Time: %5.1f" % (total_trip_time/total_trips))
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Max Wait Time: %5.1f" % max_wait_time)
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Max Trip Time: %5.1f" % max_trip_time)

    total_distance = 0
    @elevators.each do |elevator|
      distance = elevator[:car].elevator_status[:distance]
      total_distance += distance
    end
    Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "  Elevator dx  : %5.1f" % total_distance)
    @elevators.each do |elevator|
      distance = elevator[:car].elevator_status[:distance]
      Logger::msg(Simulator::time, LOGGER_MODULE, MODULE_ID, Logger::INFO, "    Elevator #{elevator[:id]} : %5.1f" % distance)
    end
  end

  # Place all occupants on their floor's waitlist at random times with destination = first floor.
  def queue_evening_occupants
    @occupants.each do |occupant|
      arrival_time = @@rng.rand(Simulator::time..Simulator::time+600)  # TODO do a normal distribution of arrival time around 5pm +/- 15
      current_floor = occupant.destination
      occupant.enq(1, arrival_time)
      @floors[current_floor].enter_waitlist(occupant)
    end
  end

  # Place all occupants on first floor waitlist at random times.
  def queue_morning_occupants
    @occupants.each do |occupant|
      destination_floor = @@rng.rand(2..@num_floors-1)
      arrival_time = @@rng.rand(0..600)  # TODO do a normal distribution of arrival time around 9am +/- 15
      occupant.enq(destination_floor, arrival_time)
      @floors[1].insert_occupant(occupant)
      @floors[1].enter_waitlist(occupant)
      end
  end

  def run_sym
    while 1
      @calls = create_call_events(@occupants)
      @calls.each do |call|
        @controller[:queue] << call
      end
      # for now, morning program is complete when there are no more waiters and no more riders.
      no_waiters = @floors.all? { |floor| floor.waitlist.length.zero? }
      no_riders = @elevators.all? { |elevator| elevator[:car].elevator_status[:riders][:occupants].length.zero?}
      break if no_waiters && no_riders
      sleep LOOP_DELAY
      @@sim_time += LOOP_TIME_INCR
    end
  end

  def self.time
    @@sim_time
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
