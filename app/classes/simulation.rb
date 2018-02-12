# Elevator operation simulator.
class Simulation

  SIM_LOOP_DELAY     = 0.01   # (seconds) - sleep delay in simulation loop.
  SIM_LOOP_TIME_INCR = 1.0    # (seconds) - amount of time to advance simulated time for each simulation loop.
  STATIC_RNG_SEED    = 101    # for random number generation.

  @@simulation_time = nil

  def initialize(logic:'FCFS', modifiers: {}, floors: 6, elevators: 1, occupants: 20, debug:false)
    @logic         = logic
    @modifiers     = modifiers
    @num_floors    = floors
    @num_elevators = elevators
    @num_occupants = occupants
    @@debug        = debug
    @@rng = Random.new(STATIC_RNG_SEED)

    @@simulation_time = 0.0   # seconds
    @floors     = create_floors(@num_floors)
    @elevators  = create_elevators(@num_elevators, @floors)
    @controller = create_controller(@elevators)
    @occupants  = create_occupants(@num_occupants)

    # @old_waiter_length = Array.new(@floors.length, 0)
  end

  def self.debug
    @@debug
  end

  def self.msg(text)
    puts "Time: %6.2f: #{text}" % Simulation::time
  end

  def self.rng
    @@rng
  end

  def run
    queue_morning_occupants
    run_sym
    output_stats
    clear_stats
    queue_evening_occupants
    run_sym
    output_stats
    # cleanup
  end

private

  # Create call events.
  def create_call_events(occupants)
    calls = []
    @floors.each do |floor|
      if !floor.waitlist.empty?
        going_dn = false
        going_up = false
        floor.waitlist.each do |occupant|
          next if !occupant.time_to_board
          going_dn ||= occupant.destination < floor.id
          going_up ||= occupant.destination > floor.id
          break if going_up && going_dn
        end
        if going_dn && !floor.call_dn
          floor.press_call_dn
          calls << {time: Simulation::time, cmd: 'CALL', floor: floor.id, direction: 'dn'}
        end
        if going_up && !floor.call_up
          floor.press_call_up
          calls << {time: Simulation::time, cmd: 'CALL', floor: floor.id, direction: 'up'}
        end
      end
    end
    calls
  end

  # Create controller.
  def create_controller(elevators)
    q = Queue.new
    c = Controller.new(q, elevators)
    t = Thread.new { c.run }
    controller = {queue: q, thread: t, controller: controller}
  end

  # Create elevators.
  def create_elevators(elevator_count, floors)
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
    occupant_count.times { |i| occupants << Occupant.new(i, Simulation::rng.rand(170..200)) }  # TODO eventually switch to normal distribution of weight. 170 +/- 29
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
    Simulation::msg 'Simulator: Simulation done.'
    Simulation::msg "Simulator:   Logic        : #{@logic}"
    Simulation::msg "Simulator:   Run Time     : %5.1f" % Simulation::time
    Simulation::msg "Simulator:   Total Trips  : %5.1f" % total_trips
    Simulation::msg "Simulator:   Avg Wait Time: %5.1f" % (total_wait_time/total_trips)
    Simulation::msg "Simulator:   Avg Trip Time: %5.1f" % (total_trip_time/total_trips)
    Simulation::msg "Simulator:   Max Wait Time: %5.1f" % max_wait_time
    Simulation::msg "Simulator:   Max Trip Time: %5.1f" % max_trip_time

    total_distance = 0
    @elevators.each do |elevator|
      distance = elevator[:car].elevator_status[:distance]
      total_distance += distance
    end
    Simulation::msg "Simulator:   Total Elevator dx: %5.1f" % total_distance
    @elevators.each do |elevator|
      distance = elevator[:car].elevator_status[:distance]
      Simulation::msg "Simulator:       Elevator #{elevator[:id]} dx: %5.1f" % distance
    end
  end

  def queue_evening_occupants
    @occupants.each do |occupant|
      destination_floor = 1
      arrival_time = @@rng.rand(Simulation::time..Simulation::time+600)  # TODO do a normal distribution of arrival time around 5pm +/- 15
      current_floor = occupant.destination
      occupant.enq(destination_floor, arrival_time)
      @floors[current_floor].enter_waitlist(occupant)
    end
  end

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

      sleep SIM_LOOP_DELAY
      @@simulation_time += SIM_LOOP_TIME_INCR
    end
  end

  def self.time
    @@simulation_time
  end








# Shutdown elevators and controller.
def cleanup
  @controller[:queue] << {time: Simulation::time, cmd: 'END'}

  # Keep clock running while waiting for elevators threads to complete.
  while @elevators.reduce(false) { |status, elevator| status || elevator[:thread].status }
    sleep LOOP_DELAY
    @@simulation_time += LOOP_TIME
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
