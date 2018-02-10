# Elevator operation simulator.
class Simulation

  LOOP_DELAY  =   0.125   # seconds.
  LOOP_TIME   =   1.0     # seconds.
  STATIC_SEED = 101

  def initialize(logic:'FCFS', modifiers: {}, floors: 6, elevators: 1, occupants: 20, debug:false)
    @@rng = Random.new(STATIC_SEED)
    @@simulation_time = 0.0   # seconds
    @logic         = logic
    @modifiers     = modifiers
    @num_floors    = floors
    @num_elevators = elevators
    @num_occupants = occupants
    @debug         = debug
    @semaphore  = Mutex.new
    @occupants  = create_occupants(@num_occupants)
    @floors     = create_floors(@num_floors, @occupants)  # read-write by simulation and elevator. Protect with mutex semaphore.
    @elevators  = create_elevators(@num_elevators, @floors)
    @controller = create_controller(@elevators)
    @old_waiter_length = Array.new(@floors.length, 0)
    queue_occupants
  end

  def self.debug
    @debug
  end

  def self.msg(text)
    puts "Time: %6.2f: #{text}" % Simulation::time
  end

  def self.rng
    @@rng
  end

  def run
    while 1
      @commands = create_commands(@floors)
      if !@commands.empty?
        if @commands[0][:time] <= Simulation::time
          Simulation::msg "Simulator: #{@commands[0]}"
          @controller[:queue] << @commands[0]
          break if @commands[0][:cmd].eql? 'END'
          @commands.shift
        end
      end
      sleep LOOP_DELAY
      @@simulation_time += LOOP_TIME
    end

    # Keep clock running while waiting for elevators to complete their commands.
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

    # Display simulation statistics.
    output_stats
  end

  def self.time
    @@simulation_time
  end

private

  # Create simulation commands.
  def create_commands(floors)
    commands = []
    any_waiting = false
    @semaphore.synchronize {
      floors.each_index do |i|
        any_waiting ||= !floors[i][:waiters].length.zero?
        if floors[i][:waiters].length != @old_waiter_length[i]
          going_up = false
          going_dn = false
          floors[i][:waiters].each do |person|
            going_up = person.destination > i
            going_dn = person.destination < i
            break if going_up && going_dn
          end
          @old_waiter_length[i] = floors[i][:waiters].length
          commands << {time: Simulation::time, cmd: 'CALL', floor: i, direction: 'up'} if going_up
          commands << {time: Simulation::time, cmd: 'CALL', floor: i, direction: 'dn'} if going_dn
        end
      end
    }
    commands << {time: Simulation::time, cmd: 'END'} if !any_waiting && @old_waiter_length.sum.zero?
    commands
  end

  # Create controller.
  def create_controller(elevators)
    q = Queue.new
    t = Thread.new('Controller') { |name| Controller.new(q, elevators).run }
    controller = {queue: q, thread: t}
  end

  # Create elevators.
  def create_elevators(num, floors)
    elevators = []
    num.times do |i|
      e_queue  = Queue.new
      e_status = Hash.new
      e_thread = Thread.new("#{i}") { |id| Elevator.new(id, e_queue, e_status, floors, @semaphore).run }
      elevators << { id: i, queue: e_queue, thread: e_thread, status: e_status }
    end
    elevators
  end

  # Create floors and place all building occupants on first floor.
  def create_floors(num, occupants)
    floors = []
    num.times { |i| floors << { occupants: [], waiters: [] } }
    floors
  end

  # Create occupants.
  def create_occupants(num)
    occupants = []
    num.times { |i| occupants << Person.new(i) }
    occupants
  end

  def output_stats
    total_trips = 0
    total_trip_time = 0.0
    total_wait_time = 0.0
    max_trip_time   = 0.0
    max_wait_time   = 0.0
    @occupants.each do |person|
      total_trips += person.completed_trips
      total_wait_time += person.total_wait_time
      total_trip_time += person.total_trip_time
      max_trip_time   = person.max_trip_time if person.max_trip_time > max_trip_time
      max_wait_time   = person.max_wait_time if person.max_wait_time > max_wait_time
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
      distance = elevator[:status][:distance]
      total_distance += distance
    end
    Simulation::msg "Simulator:   Total Elevator dx: %5.1f" % total_distance
    @elevators.each do |elevator|
      distance = elevator[:status][:distance]
      Simulation::msg "Simulator:       Elevator #{elevator[:id]} dx: %5.1f" % distance
    end
  end

  def queue_occupants
    @semaphore.synchronize {
      @occupants.each do |person|
        @floors[1][:waiters] << person
        person.on_waitlist(Simulation::time, @@rng.rand(2..@num_floors-1))
      end
    }
  end
end
