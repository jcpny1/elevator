# An Elevator moves Persons between floors of a building.
# An Elevator receives commands from the Controller.
# An Elevator has floor selection buttons that riders can press to select a destination floor.

class Elevator
  LOGGER_MODULE  = 'Elevator'
  LOOP_DELAY     = 0.01  # seconds.

  # Elevator car parameters:
  CAR_SPEED       =  4.0  # in feet per second.
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

  attr_reader :controller_q, :elevator_status

  def initialize(id, controller_q, floors)
    @id = id
    @controller_q    = controller_q         # to receive commands from the controller.
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
  #  2.   Discharge any passengers at this floor.
  #  3.   Set next direction (or hold).
  #  4.   Pickup any passengers waiting for current direction.
  #  5.   Proceed to next destination (or hold).
  def run
    prior_destination = -1
    while 1
      process_controller_commands
      destination = next_destination(@elevator_status[:destinations])
      msg "ELEVATOR LOOP: DESTINATION: #{destination}, LOCATION: #{@elevator_status[:location]}", Logger::DEBUG_3
      if destination != prior_destination
        msg "Next destination: #{destination}, Current location: #{@elevator_status[:location]}", Logger::DEBUG
        prior_destination = destination
      end

      case destination <=> @elevator_status[:location]
      when -1
        execute_command { car_move(-1) }
      when 1
        execute_command { car_move( 1) }
      when 0
        execute_command { car_arrival  }
      end
      sleep LOOP_DELAY
    end
  end

private

  # Advance the time the given amount.
  def advance_next_command_time(num)
    @elevator_status[:time] += num
  end

  # Execute arrival procedures.
  def car_arrival
    execute_command { car_stop  }
    execute_command { door_open }

    @elevator_status[:direction] = @elevator_status[:destinations][current_floor]
    msg "CAR ARRIVAL: DIRECTION1: #{@elevator_status[:direction]}", Logger::DEBUG_3

    # Discharge cycle.
    discharge_count = discharge_passengers
    msg "discharged #{discharge_count} on #{current_floor}" if discharge_count.positive?

    # Pickup cycle.
    pickup_count = pickup_passengers
    msg "picked up #{pickup_count} on #{current_floor}" if pickup_count.positive?

    # If neither picking or dropping off, stay open DOOR_WAIT_TIME.
    if (discharge_count + pickup_count).zero?
      msg 'ZERO passengers on or off', Logger::DEBUG_3
      msg 'door wait', Logger::DEBUG_3
      @elevator_status[:destinations][current_floor] = '--'
      advance_next_command_time(DOOR_WAIT_TIME)
    else
      @elevator_status[:destinations][current_floor] = nil
    end
  end

  # Move car floor_count floors. (-# = down, +# = up.)
  def car_move(floor_count)
    @elevator_status[:direction] = floor_count.negative? ? 'down' : 'up'
    @elevator_status[:location] += floor_count
    @elevator_status[:distance] += floor_count.abs * Floor::height
    execute_command { car_start }
    advance_next_command_time(floor_count.abs * (Floor::height/CAR_SPEED))
  end

  def car_start
    if @elevator_status[:car].eql? 'stopped'
      execute_command { door_close }
      msg "starting #{@elevator_status[:direction]}", Logger::DEBUG
      @elevator_status[:car] = 'moving'
      advance_next_command_time(CAR_START)
      car_status
    end
  end

  def car_status
    if @elevator_status[:car].eql? 'stopped'
      msg "#{@elevator_status[:car]} on #{@elevator_status[:location]}", Logger::DEBUG
    else
      msg "#{@elevator_status[:car]} #{@elevator_status[:direction]}", Logger::DEBUG
    end
  end

  def car_stop
    if @elevator_status[:car].eql? 'moving'
      msg "stopping on #{@elevator_status[:location]}", Logger::DEBUG
      @elevator_status[:car] = 'stopped'
      advance_next_command_time(CAR_STOP)
      car_status
    end
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
      advance_next_command_time(DISCHARGE_TIME)
      discharge_count += 1
      true
    end
    discharge_count
  end

  def door_close
    if !@elevator_status[:door].eql? 'closed'
      msg 'door closing', Logger::DEBUG
      @elevator_status[:door] = 'closed'
      advance_next_command_time(DOOR_CLOSE)
      execute_command {door_status}
    end
  end

  def door_open
    if !@elevator_status[:door].eql? 'open'
      msg 'door opening', Logger::DEBUG
      @elevator_status[:door] = 'open'
      advance_next_command_time(DOOR_OPEN)
      execute_command {door_status}
    end
  end

  def door_status
    msg "door #{@elevator_status[:door]}", Logger::DEBUG
  end

  def execute_command
    sleep LOOP_DELAY until Simulator::time >= @elevator_status[:time]
    yield
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
    status[:car] = 'stopped'  # car motion.
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
    status[:time]      = 0.0         # this status effective time.
    status
  end

  def next_destination(destinations)
    destination = @elevator_status[:location]
    msg "NEXT DESTINATION: #{destination}, DIRECTION: #{@elevator_status[:direction]}", Logger::DEBUG_3

    if going_up?
      # Return nearest stop above current location.
      up_index = destinations.slice(current_floor...@elevator_status[:destinations].length).index { |destination| !destination.nil? }

      if !up_index.nil?
        destination = up_index + current_floor

        # If car is full, don't consider current floor as a destination (for pickups only).
        if car_full? && destination == current_floor && !discharge_on?(current_floor)
          up_index = destinations.slice(current_floor + 1...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
          destination = up_index + current_floor + 1 if !up_index.nil?
        end
      end
      @elevator_status[:direction] = 'down' if up_index.nil?
    end

    if going_down?
      # Return nearest stop below current location.
      down_index = destinations.slice(0..current_floor).rindex { |destination| !destination.nil? }

      if !down_index.nil?
        destination = down_index

        # If car is full, don't consider current floor as a destination.
        if car_full? && destination == current_floor
          down_index = destinations.slice(0...current_floor).index { |destination| !destination.nil? }
          destination = down_index if !down_index.nil?
        end
      end
      @elevator_status[:direction] = '--' if down_index.nil?
    end

    if stationary?
      # Return nearest stop to current location and set appropriate @elevator_status[:direction].
      up_index = @elevator_status[:destinations].slice(current_floor+1...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
      down_index = @elevator_status[:destinations].slice(0..current_floor-1).rindex { |destination| !destination.nil? }
      if up_index.nil? && down_index.nil?
        destination = current_floor
      elsif !up_index.nil? && !down_index.nil?
        # If upper floor closer than lower floor, go up.
        if up_index < down_index
          @elevator_status[:direction] = 'up'
          destination = up_index + current_floor + 1
        else
          @elevator_status[:direction] = 'down'
          destination = down_index
        end
      elsif !up_index.nil?
        @elevator_status[:direction] = 'up'
        destination = up_index + current_floor + 1
      else
        @elevator_status[:direction] = 'down'
        destination = down_index
      end
    end
    destination
  end

  def no_destinations
    !@elevator_status[:destinations].any? { |d| !d.nil? }
  end

  # Pickup passengers from floor's wait list.
  def pickup_passengers
    pickup_count = 0
    @floors[current_floor].leave_waitlist do |passenger|
      if ((going_up? && (passenger.destination >= current_floor)) || (going_down? && (passenger.destination <= current_floor))) && !car_full?
        @elevator_status[:riders][:count]  += 1
        @elevator_status[:riders][:weight] += passenger.weight
        @elevator_status[:riders][:occupants] << passenger
        @elevator_status[:destinations][passenger.destination] = '--' if @elevator_status[:destinations][passenger.destination].nil?
        msg "Destinations: #{@elevator_status[:destinations].join(', ')}", Logger::DEBUG
        passenger.on_elevator(Simulator::time)
        advance_next_command_time(LOAD_TIME)
        pickup_count += 1
        true
      end
    end
    pickup_count
  end

  def process_controller_commands
    # Check controller for incoming commands.
    while !@controller_q.empty?
      request = @controller_q.deq
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, request.to_s)
      case request[:cmd]
      when 'CALL'
        process_floor_request(request)
      when 'END'
        drain_queue = true
      else
        raise "Invalid command: #{request[:cmd]}"
      end
    end
  end

  # Handle floor request
  def process_floor_request(request)
    request_floor = request[:floor].to_i
    @elevator_status[:destinations][request_floor] = request[:direction]
    msg "Destinations: #{@elevator_status[:destinations].join(', ')}", Logger::DEBUG
  end
end
