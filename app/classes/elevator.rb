# An Elevator moves Persons between floors of a building.
# An Elevator receives commands from the Controller.
# An Elevator has floor selection buttons that riders can press to select a destination floor.

class Elevator

  attr_reader :command_q, :distance, :floor_idx, :id, :status, :stops

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

  def initialize(id, command_q, floors)
    @id              = id                   # Elevator id.
    @command_q       = command_q            # to receive requests from the controller.
    @direction       = '--'                 # car heading = up, down, --
    @distance        = 0.0                  # cumulative distance traveled.
    @door            = 'closed'             # door status = open, opening, closed, closing.
    @floors          = floors               # array of Floor objects.
    @floor_idx       = 1                    # elevator location.
    @riders          = {count: 0,           # # of elevator occupants,
                        weight: 0.0,        # sum of occupants weight,
                        occupants: []}      # occupants of elevator.
    @status          = 'waiting'            # elevator status = executing (procesing a controller command), waiting (waiting for a command).
    @stops           = Array.new(@floors.length, false)  # stop-at-floor indicator, true or false.
    @time            = 0.0                  # elevator time, aka next available time.
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
  end

  # For coding simplicity, we'll allow boarding until car is overweight.
  # In the real world, we would board. Then once overweight, offboard until under weight.
  def car_full?
    @riders[:count] == PASSENGER_LIMIT || @riders[:weight] >= WEIGHT_LIMIT
  end

  def going_down?
    @direction == 'down'
  end

  def going_up?
    @direction == 'up'
  end

  def has_riders?
    !@riders[:count].zero?
  end

  # Reset runtime statistics
  def init_stats
    @distance = 0.0
  end

  def occupants
    @riders[:occupants]
  end

  # Main logic:
  #  1. Stop at floor
  #  2. Discharge any passengers for this floor.
  #  3. Notify controller request complete.
  #  3. Get next destination (or hold command) from contoller.
  #  4. If not holding, pickup any passengers going in same direction then proceed to next destination.
  #  5. Goto step 1.
  def run
    destination = Floor::GROUND_FLOOR
    while true
      request = @command_q.deq
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "request received: #{request}, current floor: #{@floor_idx}")
      destination = process_controller_command(request)
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "next destination: #{destination}, current floor: #{@floor_idx}")

      while true
        case @floor_idx <=> destination
        when -1
          execute_command { car_move( 1) }
        when 1
          execute_command { car_move(-1) }
        when 0
          execute_command { car_stop    }
          execute_command { car_arrival }
          discharge_passengers
          # TODO figure out why next line is not working.
          # status = 'waiting'
          @status = 'waiting'
          Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "#{@status}")
          break
        end
      end
      sleep LOOP_DELAY
    end
  end

  def stationary?
    @direction == '--'
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

  # Advance the time the given amount.
  def advance_elevator_time(num)
    @time += num
  end

  # Clear stop request button for given floor.
  def cancel_stop(floor_idx)
    @stops[floor_idx] = false
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "clearing stop. stops: #{@stops.join(', ')}")
  end

  # Elevator car arrives at a floor.
  def car_arrival
    execute_command { door_open }
    cancel_stop(@floor_idx)
  end

  # Elevator car departs a floor.
  def car_departure
    pickup_count = pickup_passengers
    going_down? ? @floors[@floor_idx].cancel_call_down : @floors[@floor_idx].cancel_call_up if !pickup_count.zero?
    execute_command { door_close }
  end

  # Move car floor_count floors. (-# = down, +# = up.)
  def car_move(floor_count)
    @direction = floor_count.negative? ? 'down' : 'up'
    @floor_idx += floor_count
    @distance += floor_count.abs * Floor::height
    execute_command { car_start }
    advance_elevator_time(floor_count.abs * (Floor::height/CAR_SPEED))
  end

  def car_start
    execute_command { door_close }
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "starting #{@direction}")
    advance_elevator_time(CAR_START)
    car_status
  end

  def car_status
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "#{@status} direction #{@direction} floor #{@floor_idx}")
  end

  def car_stop
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "stopping on #{@floor_idx}")
    advance_elevator_time(CAR_STOP)
    car_status
  end

  # Discharge riders to destination floor.
  # Returns number of passengers dicharged.
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

  def door_close
    if !@door.eql? 'closed'
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'door closing')
      @door = 'closed'
      advance_elevator_time(DOOR_WAIT_TIME)
      advance_elevator_time(DOOR_CLOSE)
      execute_command {door_status}
    end
  end

  def door_open
    if !@door.eql? 'open'
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'door opening')
      @door = 'open'
      advance_elevator_time(DOOR_OPEN)
      execute_command {door_status}
    end
  end

  def door_status
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "door #{@door}")
  end

  # Yields to a code block once simulation time catches up to elevator time.
  def execute_command
    sleep LOOP_DELAY until Simulator::time >= @time
    yield
  end

  # Pickup passengers from floor's wait list.
  # Returns number of passengers picked up.
  def pickup_passengers
    pickup_count = 0
    @floors[@floor_idx].leave_waitlist do |passenger|
      if ((going_up? && (passenger.destination > @floor_idx)) || (going_down? && (passenger.destination < @floor_idx))) && !car_full?
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
    @direction = request_floor_idx < @floor_idx ? 'down' : 'up'
    execute_command { car_departure }
    request_floor_idx
  end

  # Set stop request button for given floor.
  def set_stop(floor_idx)
    @stops[floor_idx] = true
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "adding stop. stops: #{@stops.join(', ')}")
  end
end
