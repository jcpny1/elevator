# An Elevator moves Persons between floors of a building.
# An Elevator receives commands from the Controller.
# An Elevator has floor selection buttons that riders can press to select a destination floor.

class Elevator
  LOGGER_MODULE = 'Elevator'  # for console logger.
  LOOP_DELAY    = 0.1         # (seconds) - sleep delay in main loop.

  # Elevator car parameters:
  CAR_SPEED       = 4.0   # in feet per second.
  PASSENGER_LIMIT = 10    # in bodies.
  WEIGHT_LIMIT    = 2000  # in pounds.

  # Elevator operation times (in seconds):
  CAR_START      = 1.0
  CAR_STOP       = 1.0
  DOOR_CLOSE     = 2.0
  DOOR_OPEN      = 2.0
  DISCHARGE_TIME = 2.0
  DOOR_WAIT_TIME = 3.0
  LOAD_TIME      = 2.0

  attr_reader :command_q, :elevator_status, :id

  def initialize(id, command_q, floors)
    @id              = id                   # Elevator id.
    @command_q       = command_q            # to receive requests from the controller.
    @floors          = floors               # on each floor, load from waitlist, discharge to occupant list.
    @elevator_status = new_elevator_status  # keeps track of what the elevator is doing and has done.
    init_stats
    msg 'created'
  end

  # For coding simplicity, we'll allow boarding until car is overweight.
  # In the real world, we would board. Then once overweight, offboard until under weight.
  def car_full?
    @elevator_status[:riders][:count] == PASSENGER_LIMIT ||
    @elevator_status[:riders][:weight] >= WEIGHT_LIMIT
  end

  def current_floor
    @elevator_status[:location]
  end

  def going_down?
    @elevator_status[:direction] == 'down'
  end

  def going_up?
    @elevator_status[:direction] == 'up'
  end

  def stationary?
    @elevator_status[:direction] == '--'
  end

  # Runtime statistics
  def init_stats
    @elevator_status[:distance] = 0.0  # cumulative distance traveled.
  end

  # Main logic:
  #  1. Stop at floor
  #  2. Discharge any passengers for this floor.
  #  3. Notify controller request complete.
  #  3. Get next destination (or hold command) from contoller.
  #  4. If not holding, pickup any passengers going in same direction then proceed to next destination.
  #  5. Goto step 1.
  def run
    while 1
      request = @command_q.deq
      msg "Requst received: #{request.to_s}, Current location: #{@elevator_status[:location]}", Logger::DEBUG
      destination = process_controller_command(request)
      msg "Next destination: #{destination}, Current location: #{@elevator_status[:location]}", Logger::DEBUG
      case destination <=> @elevator_status[:location]
      when -1
        execute_command { car_move(-1) }
      when 1
        execute_command { car_move( 1) }
      when 0
        execute_command { car_stop    }
        execute_command { car_arrival }
        execute_command { car_waiting }
      end
      sleep LOOP_DELAY
    end
  end

private

  # Advance the time the given amount.
  def advance_elevator_time(num)
    @elevator_status[:time] += num
  end

  # Elevator car arrives at a floor.
  def car_arrival
    execute_command { door_open }
    discharge_passengers
  end

  # Elevator car departs a floor.
  def car_departure
    pickup_passengers
    execute_command { door_close }
  end

  # Yields to a code block once simulation time catches up to elevator time.
  def execute_command
    sleep LOOP_DELAY until Simulator::time >= @elevator_status[:time]
    yield
  end

  # Pickup passengers from floor's wait list.
  def pickup_passengers
    pickup_count = 0
    @floors[current_floor].leave_waitlist do |passenger|
      if ((going_up? && (passenger.destination > current_floor)) || (going_down? && (passenger.destination < current_floor))) && !car_full?
        @elevator_status[:riders][:count]  += 1
        @elevator_status[:riders][:weight] += passenger.weight
        @elevator_status[:riders][:occupants] << passenger
        @elevator_status[:stops][passenger.destination] = true
        msg "Destinations: #{@elevator_status[:destinations].join(', ')}", Logger::DEBUG
        passenger.on_elevator(Simulator::time)
        advance_elevator_time(LOAD_TIME)
        pickup_count += 1
        true
      end
    end
    msg "picked up #{pickup_count} on #{current_floor}" if pickup_count.positive?
    pickup_count
  end

  # Process controller request.
  def process_controller_command(request)
    case request[:cmd]
    when 'GOTO'
      process_goto_request(request)
    when 'END'
    else
      raise "Invalid command: #{request[:cmd]}"
    end
  end

  # Handle GOTO command.
  def process_goto_request(request)
    request_floor = request[:floor_idx].to_i
    @elevator_status[:stops][request_floor] = true
    msg "Destinations: #{@elevator_status[:stops].join(', ')}", Logger::DEBUG
    @elevator_status[:direction] = request_floor < current_floor ? 'down' : 'up'
    execute_command { car_departure }
    request_floor
  end





  # @elevator_status[:direction] = @elevator_status[:destinations][current_floor]

  # Move car floor_count floors. (-# = down, +# = up.)
  def car_move(floor_count)
    @elevator_status[:direction] = floor_count.negative? ? 'down' : 'up'
    @elevator_status[:location] += floor_count
    @elevator_status[:distance] += floor_count.abs * Floor::height
    execute_command { car_start }
    advance_elevator_time(floor_count.abs * (Floor::height/CAR_SPEED))
  end

  def car_start
    if !@elevator_status[:car].eql? 'moving'
      execute_command { door_close }
      msg "starting #{@elevator_status[:direction]}", Logger::DEBUG
      @elevator_status[:car] = 'moving'
      advance_elevator_time(CAR_START)
      car_status
    end
  end

  def car_status
    if !@elevator_status[:car].eql? 'moving'
      msg "#{@elevator_status[:car]} on #{@elevator_status[:location]}", Logger::DEBUG
    else
      msg "#{@elevator_status[:car]} #{@elevator_status[:direction]}", Logger::DEBUG
    end
  end

  def car_stop
    if @elevator_status[:car].eql? 'moving'
      msg "stopping on #{@elevator_status[:location]}", Logger::DEBUG
      @elevator_status[:car] = 'stopped'
      advance_elevator_time(CAR_STOP)
      car_status
    end
  end

  # Elevator car is available for another request.
  def car_waiting
    @elevator_status[:car] = 'waiting'
    msg "Car waiting"
  end

  # Discharge riders to destination floor.
  def discharge_passengers
    discharge_count = 0
    floor = @floors[current_floor]
    @elevator_status[:riders][:occupants].delete_if do |passenger|
      next if passenger.destination != floor.id
      passenger.on_floor(Simulator::time)
      floor.accept_occupant(passenger)
      @elevator_status[:riders][:count]  -= 1
      @elevator_status[:riders][:weight] -= passenger.weight
      advance_elevator_time(DISCHARGE_TIME)
      discharge_count += 1
      true
    end
    msg "discharged #{discharge_count} on #{current_floor}" if discharge_count.positive?
    discharge_count
  end

  def door_close
    if !@elevator_status[:door].eql? 'closed'
      msg 'door closing', Logger::DEBUG
      @elevator_status[:door] = 'closed'
      advance_elevator_time(DOOR_WAIT_TIME)
      advance_elevator_time(DOOR_CLOSE)
      execute_command {door_status}
    end
  end

  def door_open
    if !@elevator_status[:door].eql? 'open'
      msg 'door opening', Logger::DEBUG
      @elevator_status[:door] = 'open'
      advance_elevator_time(DOOR_OPEN)
      execute_command {door_status}
    end
  end

  def door_status
    msg "door #{@elevator_status[:door]}", Logger::DEBUG
  end

# TODO remove this method when all converted to Logger
  def msg(text_msg, debug_level = Logger::DEBUG)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, debug_level, text_msg)
  end

  # Are any riders getting off on specified floor?
  def discharge_on?(floor)
    @elevator_status[:riders][:occupants].any? { |occupant| occupant.destination == floor }
  end

  # Create an elevator status object. (Will have multithreaded read access.)
  def new_elevator_status
    status = {}
    # Car values:
    #   'moving'  = car is moving to a floor.
    #   'stopped' = car is stopped at a floor.
    #   'waiting' = car is waiting for instructions.
    status[:car] = 'waiting'  # car motion.
  # Direction values:
    #   'up' = car is heading up.
    #   'down' = car is heading down.
    #   '--' = car is stationary.
    status[:direction] = '--'
  # Destinations values:
  #   'up' = call on floor on to go up.
  #   'down' = call on floor to to down.
  #   '--' = no call, discharge stop.
  #   nil = no call, no stop.
    status[:destinations] = Array.new(@floors.length)  # floors for this elevator is requested to stop at.
    status[:door]      = 'closed'    # door status.
    status[:location]  = 1           # floor.
    status[:riders]    = {count: 0, weight: 0, occupants: []}  # occupants
    status[:stops]     = Array.new(@floors.length, false)  # floors this elevator is requested to visit.
    status[:time]      = 0.0         # this status effective time.
    status
  end

  def no_destinations
    !@elevator_status[:destinations].any? { |d| !d.nil? }
  end

end
