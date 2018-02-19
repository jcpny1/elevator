# An Elevator moves Persons between floors of a building.
# An Elevator receives commands from the Controller.
# An Elevator has floor selection buttons that riders can press to select a destination floor.

class Elevator

  attr_reader :command_q, :elevator_status, :id

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
    @floors          = floors               # on each floor, load from waitlist, discharge to occupant list.
    @elevator_status = new_elevator_status  # keeps track of what the elevator is doing and has done.
    init_stats
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
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

  def direction
    @elevator_status[:direction]
  end

  def going_down?
    @elevator_status[:direction] == 'down'
  end

  def going_up?
    @elevator_status[:direction] == 'up'
  end

  def has_riders?
    !@elevator_status[:riders][:count].zero?
  end

  # Reset runtime statistics
  def init_stats
    @elevator_status[:distance] = 0.0  # cumulative distance traveled.
  end

  # Return elevator's next stop.
  def next_stop
    stop = nil
    if going_down?
      # return next true value in stops list below current stop.
      # if none, error.
      stop = next_stop_down
      raise "going down without a destination" if stop.nil?
    elsif going_up?
      # return next true value in stops list above current stop.
      # if none, error.
      stop = next_stop_up
      raise "going up without a destination" if stop.nil?
    else
      # waiting.
      # return closest stop in any direction.
      down_stop = next_stop_down
      up_stop = next_stop_up

      if down_stop.nil?
        stop = up_stop
      elsif up_stop.nil?
        stop = down_stop
      else
        # for now, we'll bias equidistant stops to the up direction.
        # we may want to adjust that with time-of-day optimizations.
        dn_stop_diff = current_floor - dn_stop
        up_stop_diff = up_stop - current_floor
        stop = dn_stop_diff < up_stop_diff ? dn_stop : up_stop
      end
    end
  end

  def next_stop_down
    @elevator_status[:stops].slice(0...current_floor).rindex { |stop| stop }
  end

  def next_stop_up
    @elevator_status[:stops].slice(current_floor + 1...@elevator_status[:stops].length).index { |stop| stop }
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
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "requst received: #{request}, current location: #{@elevator_status[:location]}")
      destination = process_controller_command(request)
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "next destination: #{destination}, current location: #{@elevator_status[:location]}")

      while true
        case current_floor <=> destination
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
          @elevator_status[:car] = 'waiting'
          Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "#{@elevator_status[:car]}")
          break
        end
      end
      sleep LOOP_DELAY
    end
  end

  def status
    @elevator_status[:car]
  end

  def status=(s)
    @elevator_status[:car] = s
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "#{s}")
  end

  def stationary?
    @elevator_status[:direction] == '--'
  end

  def waiting?
    status == 'waiting'
  end

private

  # Advance the time the given amount.
  def advance_elevator_time(num)
    @elevator_status[:time] += num
  end

  # Clear stop request button for given floor.
  def cancel_stop(floor_idx)
    @elevator_status[:stops][floor_idx] = false
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "clearing stop. stops: #{@elevator_status[:stops].join(', ')}")
  end

  # Elevator car arrives at a floor.
  def car_arrival
    execute_command { door_open }
    cancel_stop(current_floor)
  end

  # Elevator car departs a floor.
  def car_departure
    pickup_count = pickup_passengers
    going_down? ? @floors[current_floor].cancel_call_down : @floors[current_floor].cancel_call_up if !pickup_count.zero?
    execute_command { door_close }
  end

  # Move car floor_count floors. (-# = down, +# = up.)
  def car_move(floor_count)
    @elevator_status[:direction] = floor_count.negative? ? 'down' : 'up'
    @elevator_status[:location] += floor_count
    @elevator_status[:distance] += floor_count.abs * Floor::height
    execute_command { car_start }
    advance_elevator_time(floor_count.abs * (Floor::height/CAR_SPEED))
  end

  def car_start
    execute_command { door_close }
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "starting #{@elevator_status[:direction]}")
    advance_elevator_time(CAR_START)
    car_status
  end

  def car_status
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "#{status} floor #{current_floor} direction #{direction}")
  end

  def car_stop
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "stopping on #{@elevator_status[:location]}")
    advance_elevator_time(CAR_STOP)
    car_status
  end

  # Discharge riders to destination floor.
  # Returns number of passengers dicharged.
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
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "discharged #{discharge_count} on #{current_floor}") if !discharge_count.zero?
    discharge_count
  end

  def door_close
    if !@elevator_status[:door].eql? 'closed'
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'door closing')
      @elevator_status[:door] = 'closed'
      advance_elevator_time(DOOR_WAIT_TIME)
      advance_elevator_time(DOOR_CLOSE)
      execute_command {door_status}
    end
  end

  def door_open
    if !@elevator_status[:door].eql? 'open'
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'door opening')
      @elevator_status[:door] = 'open'
      advance_elevator_time(DOOR_OPEN)
      execute_command {door_status}
    end
  end

  def door_status
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "door #{@elevator_status[:door]}")
  end

  # Yields to a code block once simulation time catches up to elevator time.
  def execute_command
    sleep LOOP_DELAY until Simulator::time >= @elevator_status[:time]
    yield
  end

  # Create an elevator status object. (Will have multithreaded read access.)
  def new_elevator_status
    status = {}
    # Car values:
    #   'executing' = car is processing a command.
    #   'waiting'   = car is waiting for instructions.
    status[:car] = 'waiting'  # car status.
  # Direction values:
    #   'up' = car is heading up.
    #   'down' = car is heading down.
    #   '--' = car is stationary.
    status[:direction] = '--'
    status[:door]      = 'closed'    # door status.
    status[:location]  = 1           # floor.
    status[:riders]    = {count: 0, weight: 0, occupants: []}  # occupants
    status[:stops]     = Array.new(@floors.length, false)  # floors this elevator is requested to visit.
    status[:time]      = 0.0         # this status effective time.
    status
  end

  # Pickup passengers from floor's wait list.
  # Returns number of passengers picked up.
  def pickup_passengers
    pickup_count = 0
    @floors[current_floor].leave_waitlist do |passenger|
      if ((going_up? && (passenger.destination > current_floor)) || (going_down? && (passenger.destination < current_floor))) && !car_full?
        @elevator_status[:riders][:count]  += 1
        @elevator_status[:riders][:weight] += passenger.weight
        @elevator_status[:riders][:occupants] << passenger
        set_stop(passenger.destination)
        passenger.on_elevator(Simulator::time, @id)
        advance_elevator_time(LOAD_TIME)
        pickup_count += 1
        true
      end
    end
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::INFO, "picked up #{pickup_count} on #{current_floor}") if !pickup_count.zero?
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
    set_stop(request_floor)
    @elevator_status[:direction] = request_floor < current_floor ? 'down' : 'up'
    execute_command { car_departure }
    request_floor
  end

  # Set stop request button for given floor.
  def set_stop(floor_idx)
    @elevator_status[:stops][floor_idx] = true
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "adding stop. stops: #{@elevator_status[:stops].join(', ')}")
  end
end
