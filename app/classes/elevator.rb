# An Elevator moves Persons between floors of a building.
# An Elevator receives commands from the Controller.
# An Elevator has floor selection buttons that riders can press to select a destination floor.

class Elevator

  attr_reader :command_q, :distance, :floor_idx, :id, :status, :stops

  LOGGER_MODULE = 'Elevator'  # for console logger.
  LOOP_DELAY    = 0.050       # (seconds) - sleep delay in main loop.

  # Elevator parameters:
  CAR_SPEED       = 4.0   # in feet per second.
  PASSENGER_LIMIT = 10    # in bodies.
  WEIGHT_LIMIT    = 2000  # in pounds.

  # Elevator operation times (in seconds):
  CAR_START      = 1.0  # time to go from stopped to moving.
  CAR_STOP       = 1.0  # time to go from moving to stopped.
  DISCHARGE_TIME = 2.0  # time to offboard each passenger.
  DOOR_CLOSE     = 2.0  # time for doors to close.
  DOOR_OPEN      = 2.0  # time for doors to open.
  DOOR_WAIT_TIME = 3.0  # time doors stay open after last offboard or onboard.
  LOAD_TIME      = 2.0  # time to onboard each passenger.

  def initialize(id, command_q, floors)
    @id        = id               # Elevator Id.
    @command_q = command_q        # receives requests from the controller.
    @direction = 'none'           # heading = up, down, or none.
    @distance  = 0.0              # cumulative distance traveled.
    @door      = 'closed'         # door status = open or closed.
    @floors    = floors           # array of Floor objects.
    @floor_idx = 1                # current location.
    @motion    = 'stopped'        # current movement. stopped or moving.
    @riders    = {count: 0,       # number of occupants,
                  weight: 0.0,    # sum of occupants weight,
                  occupants: []}  # occupant list.
    @status    = 'waiting'        # status = executing (a controller command) or waiting (for a command).
    @stops     = Array.new(@floors.length, false)  # stop-at-floor indicator, true or false.
    @time      = 0.0              # elevator time, aka next available time.
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
  end

  # Is elevator going down?
  def going_down?
    @direction == 'down'
  end

  # Is elevator going up?
  def going_up?
    @direction == 'up'
  end

  # Does elevator have riders?
  def has_riders?
    !@riders[:count].zero?
  end

  # Reset runtime statistics
  def init_stats
    @distance = 0.0
  end

  # Return elevator occupant list.
  def occupants
    @riders[:occupants]
  end

  # Basic logic:
  #  1. Receive destination from Controller.
  #  2. Stop at destination floor.
  #  3. Discharge any passengers for this floor.
  #  4. Pickup any passengers going in same direction.
  #  5. Proceed to next destination floor.
  #  6. Goto step 1.
  def run
    destination = Floor::GROUND_FLOOR
    while true
      if !@command_q.empty?
        request = @command_q.deq
        Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "request received: #{request}, current floor: #{@floor_idx}")
        destination = process_controller_command(request)
        execute_command { car_departure }
      end
      case @floor_idx <=> destination
      when -1
        execute_command { car_move( 1) }
      when 1
        execute_command { car_move(-1) }
      when 0
        execute_command { car_arrival }
        discharge_passengers
        Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "waiting") if @status != 'waiting'
        @status = 'waiting'
      end
      sanity_check if Logger::debug_on
      sleep LOOP_DELAY
    end
  end

  # Does elevator have no direction?
  def stationary?
    @direction == 'none'
  end

  # Alter elevator status.
  def status=(s)
    @status = s
  end

  # Return list of elevator stops.
  def waiting?
    @status == 'waiting'
  end

private

  # Advance elevator time the given amount.
  def advance_elevator_time(num)
    @time += num
  end

  # Clear stop request button for given floor.
  def cancel_stop(floor_idx)
    if @stops[floor_idx]
      @stops[floor_idx] = false
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "clearing stop. stops: #{@stops.join(', ')}")
    end
  end

  # Elevator car arrives at a floor.
  def car_arrival
    execute_command { car_stop  }
    execute_command { door_open }
    cancel_stop(@floor_idx)
  end

  # Elevator car departs a floor.
  def car_departure
    (going_down? ? @floors[@floor_idx].cancel_call_down : @floors[@floor_idx].cancel_call_up) if !pickup_passengers.zero?
    execute_command { door_close }
  end

  # Move car floor_count floors. (+=up/-=down)
  def car_move(floor_count)
    @direction = floor_count.negative? ? 'down' : 'up'
    @floor_idx += floor_count
    @distance += floor_count.abs * Floor::height
    execute_command { car_start }
    advance_elevator_time(floor_count.abs * (Floor::height/CAR_SPEED))
  end

  # Sart car movement.
  def car_start
    if @motion != 'moving'
      execute_command { door_close }
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "starting #{@direction}")
      advance_elevator_time(CAR_START)
      @motion = 'moving'
      car_status
    end
  end

  # Display car status.
  def car_status
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "status: #{@status}, motion: #{@motion}, direction: #{@direction}, floor: #{@floor_idx}")
  end

  # Stop car movement.
  def car_stop
    if @motion != 'stopped'
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "stopping on #{@floor_idx}")
      advance_elevator_time(CAR_STOP)
      @motion = 'stopped'
      car_status
    end
  end

  # Discharge riders to destination floor.
  # Return number of passengers discharged.
  def discharge_passengers
    discharge_count = 0
    floor = @floors[@floor_idx]
    occupants.delete_if do |passenger|
      next if passenger.destination != floor.id
      passenger.on_floor(Simulator::time)
      floor.accept_occupant(passenger)
      @riders[:count]  -= 1
      @riders[:weight] -= passenger.weight
      advance_elevator_time(DISCHARGE_TIME)
      discharge_count += 1
      true
    end
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "discharged #{discharge_count} on #{@floor_idx}") if !discharge_count.zero?
    discharge_count
  end

  # Close car doors.
  def door_close
    if !@door.eql? 'closed'
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'door closing')
      @door = 'closed'
      advance_elevator_time(DOOR_CLOSE)
      execute_command { door_status }
    end
  end

  # Open car doors.
  def door_open
    if !@door.eql? 'open'
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'door opening')
      @door = 'open'
      advance_elevator_time(DOOR_OPEN)
      execute_command { door_status }
    end
  end

  # Display door status.
  def door_status
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "door #{@door}")
  end

  # Yield to a code block once simulation time catches up to elevator time.
  def execute_command
    sleep LOOP_DELAY until Simulator::time >= @time
    yield
  end

  # Is elevator full?
  # For coding simplicity, we'll allow boarding until car is overweight.
  # In the real world, we would board. Then once overweight, offboard until under weight.
  def full?
    @riders[:count] == PASSENGER_LIMIT || @riders[:weight] >= WEIGHT_LIMIT
  end

  # Pickup passengers from floor's wait list.
  # Return number of passengers picked up.
  def pickup_passengers
    pickup_count = 0
    @floors[@floor_idx].leave_waitlist do |passenger|
      if ((going_up? && (passenger.destination > @floor_idx)) || (going_down? && (passenger.destination < @floor_idx))) && !full?
        @riders[:count]  += 1
        @riders[:weight] += passenger.weight
        occupants << passenger
        set_stop(passenger.destination)
        passenger.on_elevator(Simulator::time, @id)
        advance_elevator_time(LOAD_TIME)
        pickup_count += 1
        true
      end
    end
    advance_elevator_time(DOOR_WAIT_TIME)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "picked up #{pickup_count} on #{@floor_idx}") if !pickup_count.zero?
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
    request_floor_idx = request[:floor_idx].to_i
    set_stop(request_floor_idx)
    case request_floor_idx <=> @floor_idx
    when -1
      @direction = 'down'
    when 0
      # Elevator is already at destination floor. See if there's a call here to set direction.
      if @floors[@floor_idx].call_down
        @direction = 'down'
      elsif @floors[@floor_idx].call_up
        @direction = 'up'
      else
        @direction = 'none'
      end
    when 1
      @direction = 'up'
    end
    request_floor_idx
  end

  # Check for error conditions.
  def sanity_check
    # Don't travel below ground floor or above top floor.
    raise "Elevator #{@id} out-of-bounds on floor #{@floor_idx}" if (@floor_idx < Floor::GROUND_FLOOR || @floor_idx >= @floors.length)
    # Don't have riders going up AND riders going down.
    rider_going_down = false
    rider_going_up = false
    occupants.each do |occupant|
      rider_going_down ||= occupant.destination < @floor_idx
      rider_going_down ||= occupant.destination > @floor_idx
    end
    raise "Elevator #{@id} has riders in oppostite directions" if (rider_going_down && rider_going_up)
    raise "Elevator #{@id} moving with doors open" if ((!@door.eql? 'closed') && (!@motion.eql? 'stopped'))
  end

  # Set stop request button for given floor.
  def set_stop(floor_idx)
    if !@stops[floor_idx]
      @stops[floor_idx] = true
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "adding stop. stops: #{@stops.join(', ')}")
    end
  end
end
