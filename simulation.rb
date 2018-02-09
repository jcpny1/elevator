require 'pry'
require_relative 'app/classes/controller'
require_relative 'app/classes/elevator'
require_relative 'app/classes/person'

# Elevator operation simulator.
class Simulation

  NUM_ELEVATORS =  1
  NUM_FLOORS    =  7  # => active floors 1 -> NUM_FLOORS.
  NUM_OCCUPANTS = 20

  @@simulation_time = 0.0  # seconds

  def initialize
    @occupants  = create_occupants(NUM_OCCUPANTS)
    @floors     = create_floors(NUM_FLOORS, @occupants)
    @elevators  = create_elevators(NUM_ELEVATORS)
    @controller = create_controller(@elevators)
    @commands   = create_commands
  end

  def run
    while !@commands.empty?
      if @commands[0][:time] <= Simulation::time
puts @commands[0]
        @controller[:queue] << @commands[0]
        @commands.shift
      end
      sleep 1.0
      @@simulation_time += 1.0
puts Simulation::time
    end

    # Keep clock running while waiting for elevators to complete their commands.
    while @elevators.reduce(false) { |status, elevator| status || elevator[:thread].status }
      sleep 1.0
      @@simulation_time += 1.0
    end

    puts "Simulation done. Simulated time: #{Simulation::time}"

    # Clean up controller.
    @controller[:thread].join()
    @controller[:queue].close

    # Clean up elevators.
    @elevators.each do |elevator|
      elevator[:thread].join()
      elevator[:queue].close
      puts "Elevator #{elevator[:id]}: #{elevator[:status]}"
    end
  end

  def self.time
    @@simulation_time
  end

private

  # Create simulation commands.
  def create_commands
    commands = []
    commands << {time: 3.0, cmd: 'CALL', floor: 1, direction: 'up', pickup: [3,2,4]}
    commands << {time: 6.0, cmd: 'END'}
  end

  # Create controller.
  def create_controller(elevators)
    q = Queue.new
    t = Thread.new('Controller') { |name| Controller.new(q, elevators).run }
    controller = {queue: q, thread: t}
  end

  # Create elevators.
  def create_elevators(num)
    elevators = []
    num.times do |i|
      e_queue  = Queue.new
      e_status = Hash.new
      e_thread = Thread.new("#{i}") { |id| Elevator.new(id, e_queue, e_status).run }
      elevators << { id: i, queue: e_queue, thread: e_thread, status: e_status }
    end
    elevators
  end

  # Create floors and place all building occupants on first floor.
  def create_floors(num, occupants)
    floors = []
    num.times { |i| floors << { occupants: [], waiters: [] } }
    floors[1][:occupants] = occupants
    floors
  end

  # Create occupants.
  def create_occupants(num)
    occupants = []
    num.times { |i| NUM_OCCUPANTS.times { |i| occupants << Person.new(i, (i%(NUM_FLOORS-2))+2) } }
    occupants
  end
end

  Simulation.new.run

  #
  # puts '  GOTO 6'
  # controller_q << {cmd: 'GOTO', floor: '6', pickup: [4, 2, 1]}   # pickup: array of passengers' destinations, 1 per passenger boarding
  # puts '  CALL 2 UP'
  # controller_q << {cmd: 'CALL', floor: '2', direction: 'up', pickup: [4]}   # pickup: array of passengers' destinations, 1 per passenger boarding
  # puts '  GOTO 4'
  # controller_q << {cmd: 'CALL', floor: '4', direction: 'up', pickup: []}   # pickup: array of passengers' destinations, 1 per passenger boarding
  # puts '  GOTO 1'
  # controller_q << {cmd: 'CALL', floor: '1', direction: 'up', pickup: []}   # pickup: array of passengers' destinations, 1 per passenger boarding
  #
  # puts '  END'
  # controller_q << {cmd: Controller::END_OF_SIMULATION}
  # controller_t.join()
  # controller_q.close
