# An Elevator moves Persons between floors of a building.
class Elevator

  attr_reader :controller_q, :elevator_status

  DISTANCE_PER_FLOOR  = 12.0
  DISTANCE_PER_SECOND =  4.0
  DISTANCE_UNITS      = 'Feet'
  LOGGER_MODULE       = 'Elevator'

  CAR_START = 1.0
  CAR_STOP = 1.0
  DOOR_CLOSE = 2.0
  DOOR_OPEN = 2.0
  DISCHARGE_TIME_PER_PASSENGER = 2.0
  DOOR_WAIT_TIME = 3.0
  LOAD_TIME_PER_PASSENGER = 2.0
  LOOP_DELAY = 0.01  # seconds.

  PASSENGER_LIMIT = 10
  WEIGHT_LIMIT = 2000

  def initialize(id, controller_q, floors)
    @id = id
    @controller_q = controller_q   # to receive commands from the controller.
    @floors = floors               # on each floor, load from waitlist, discharge to occupant list.

    # Elevator Status (multithreaded r/o access. r/w in this thread only.)
    @elevator_status = {}
    @elevator_status[:car]       = 'stopped'   # car motion.
# Direction values:
    #   'up' = car is heading up.
    #   'dn' = car is heading down.
    #   '--' = car is stationary.
    @elevator_status[:direction] = '--'
# Destinations values:
#   'up' = call on floor on to go up.
#   'dn' = call on floor to to down.
#   '--' = no call, discharge stop.
#   nil = no call, no stop.
    @elevator_status[:destinations] = Array.new(@floors.length)  # floors for this elevator is requested to stop at.
    @elevator_status[:door]      = 'closed'    # door status.
    @elevator_status[:location]  = 1           # floor.
    @elevator_status[:riders]    = {count: 0, weight: 0, occupants: []}  # occupants
    @elevator_status[:time]      = 0.0         # this status effective time.
    init_stats
    msg 'active'
  end

  # For coding simplicity, we'll allow boarding until car is overweight.
  # In real world, we would board. Then once overweight, offboard until under weight.
  def car_full?
    @elevator_status[:riders][:count] == PASSENGER_LIMIT ||
    @elevator_status[:riders][:weight] >= WEIGHT_LIMIT
  end

  def current_floor
    @elevator_status[:location]
  end

  def going_down?
    @elevator_status[:direction] === 'dn'
  end

  def going_up?
    @elevator_status[:direction] === 'up'
  end

  def stationary?
    @elevator_status[:direction] === '--'
  end

  # Runtime statistics
  def init_stats
    @elevator_status[:distance]  = 0.0         # cumulative distance traveled.
  end

  def run
    drain_queue = false
    while 1

      # Check controller for incoming commands.
      while !@controller_q.empty?
        request = @controller_q.deq
        case request[:cmd]
        when 'CALL'
          msg "#{request}", Logger::DEBUG
          process_floor_request(request)
        when 'END'
          drain_queue = true
        else
          raise "Invalid command: #{request[:cmd]}."
        end
      end

      # Execute next command.
      if Simulator::time >= @elevator_status[:time]
        if no_destinations
# IS NEXT LINE NEEDED?
          @elevator_status[:direction] = '--'
          break if drain_queue
        else
# IS NEXT LINE NEEDED?
          @elevator_status[:time] = Simulator::time if @elevator_status[:time] === 0.0
          destination = next_destination(@elevator_status[:destinations])
          msg "Next destination: #{destination}, Current location: #{@elevator_status[:location]}", Logger::DEBUG
          car_move(destination <=> @elevator_status[:location])
        end
      end
      sleep LOOP_DELAY
    end
    msg 'done'
  end

private

  # Advance the time the given amount.
  def advance_next_command_time(num)
    @elevator_status[:time] += num
  end

  # Execute arrival procedures.
  def car_arrival
    execute_command { car_stop }
    execute_command { door_open }

    # Discharge cycle.
    discharge_count = discharge_passengers
    msg "discharging #{discharge_count} on #{current_floor}" if discharge_count.positive?

# if stopping here for a down call, pickup down passengers and proceed down.
# if moving up to get a down call, we should not be picking up any passengers until we arrive at call floor.
# if moving down to get an up call, we should not be picking up any passengers until we arrive at call floor.
# Sooo there's elevator movement direction, and elevator call floor direction.

#TAKE THIS OUT. WILL SET DIRECTION BASED ON CALL DIRECTION. YOU CANT CALL 6 UP or 1 DN.
    if current_floor === @floors.length - 1  # If at top floor,
      @elevator_status[:direction] = 'dn'
    elsif current_floor === 1  # If at first floor
      @elevator_status[:direction] = 'up'
    end
    # Pickup cycle.
    pickup_count = pickup_passengers
    msg "picking up #{pickup_count} on #{current_floor}" if pickup_count.positive?

    destination_direction = @elevator_status[:destinations][current_floor]
    if destination_direction != '--'
      if destination_direction === 'dn'
        @floors[current_floor].cancel_call_down
      elsif destination_direction === 'up'
        @floors[current_floor].cancel_call_up
      end
    end

    @elevator_status[:destinations][current_floor] = nil

    # going_down? ? @floors[current_floor].cancel_call_down : @floors[current_floor].cancel_call_up  # Canceling calls here. If pasengers can't board, they'll have to call again.

    # If neither picking or dropping off, stay open DOOR_WAIT_TIME.
    if (discharge_count + pickup_count).zero?
msg 'ZERO passengers on or off'
msg 'door wait'
      advance_next_command_time(DOOR_WAIT_TIME)
    end
  end

  # Move number of floors indicated. -# = down, +# = up, 0 = arrived.
  def car_move(floor_count)
    if floor_count.zero?
      execute_command { car_arrival }
#IS THIS NEEDED? IS THIS DUP SOMEWHERE ELSE?
      @elevator_status[:direction] = '--' if no_destinations
    else
      @elevator_status[:direction] = floor_count.negative? ? 'dn' : 'up'
      @elevator_status[:location] += floor_count
      @elevator_status[:distance] += floor_count.abs * DISTANCE_PER_FLOOR
      execute_command { car_start }
      advance_next_command_time(floor_count.abs * (DISTANCE_PER_FLOOR/DISTANCE_PER_SECOND))
    end
  end

  def car_start
    if @elevator_status[:car].eql? 'stopped'
      execute_command { door_close }
      msg "starting #{@elevator_status[:direction]}", Logger::DEBUG
      @elevator_status[:car] = 'moving'
      advance_next_command_time(CAR_START)
      execute_command {car_status}
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
      execute_command {car_status}
    end
  end

  # Discharge riders to destination floor.
  def discharge_passengers
    discharge_count = 0
    floor = @floors[current_floor]
    passengers = @elevator_status[:riders][:occupants].find_all { |occupant| occupant.destination === floor.id }
    passengers.each do |passenger|
      floor.enter_floor(passenger)
      @elevator_status[:riders][:count]  -= 1
      @elevator_status[:riders][:weight] -= passenger.weight
      @elevator_status[:riders][:occupants].delete(passenger)
      advance_next_command_time(DISCHARGE_TIME_PER_PASSENGER)
      discharge_count += 1
    end
    @elevator_status[:direction] = '--' if @elevator_status[:riders][:count].zero?
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
  def msg(text_msg, debug_level = Logger::INFO)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, debug_level, text_msg)
  end

  # Are any riders getting off on specified floor?
  def discharge_on?(floor)
    @elevator_status[:riders][:occupants].any? { |occupant| occupant.destination === floor }
  end


  def next_destination(destinations)
    destination = nil

    if going_up?
      # Return nearest stop above current location.
      up_index = destinations.slice(current_floor...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
      destination = up_index + current_floor

      # If car is full, don't consider current floor as a destination for pickups only.
      if car_full? && destination === current_floor && !discharge_on?(current_floor)
        up_index = destinations.slice(current_floor + 1...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
        destination = up_index + current_floor + 1
      end

      if up_index.nil?
        @elevator_status[:direction] = 'dn'
      end
    end

    if going_down?
      # Return nearest stop below current location.
      down_index = destinations.slice(0..current_floor).rindex { |destination| !destination.nil? }
      destination = down_index

      # If car is full, don't consider current floor as a destination.
      if car_full? && destination === current_floor
        down_index = destinations.slice(0...current_floor).index { |destination| !destination.nil? }
        destination = down_index
      end

      if down_index.nil?
        @elevator_status[:direction] = '--'
      end
    end

    if stationary?
      # Return nearest stop to current location and set appropriate direction.
      up_index = @elevator_status[:destinations].slice(current_floor...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
      down_index = @elevator_status[:destinations].slice(0..current_floor).rindex { |destination| !destination.nil? }
      if up_index.nil? && down_index.nil?
        # do nothing
      elsif !up_index.nil? && !down_index.nil?
        # If upper floor closer than lower floor, go up.
        if up_index < down_index
          @elevator_status[:direction] = 'up'
          destination = up_index + current_floor
        else
          @elevator_status[:direction] = 'dn'
          destination = down_index
        end
      elsif !up_index.nil?
        @elevator_status[:direction] = 'up'
        destination = up_index + current_floor
      else
        @elevator_status[:direction] = 'dn'
        destination = down_index
      end
    end
    destination
  end

  def no_destinations
    @elevator_status[:destinations].none? { |d| !d.nil? }
  end

  # Pickup passengers from floor's wait list.
  def pickup_passengers
    pickup_count = 0
    floor = @floors[current_floor]
    passengers = floor.waitlist
    passengers.each do |passenger|
      next if !passenger.time_to_board
      next if going_up? && (passenger.destination < current_floor)
      next if going_down? && (passenger.destination > current_floor)
      break if car_full?
      floor.leave_waitlist(passenger).on_elevator(Simulator::time)
      @elevator_status[:riders][:count]  += 1
      @elevator_status[:riders][:weight] += passenger.weight
      @elevator_status[:riders][:occupants] << passenger
      @elevator_status[:destinations][passenger.destination] = '--'
      advance_next_command_time(LOAD_TIME_PER_PASSENGER)
      pickup_count += 1
    end
    pickup_count
  end

  # Handle floor request
  def process_floor_request(request)

    request_floor = request[:floor].to_i
    #
    # # If @destinations is empty, just push request floor on.
    # if @destinations.empty?
    #   @destinations << request_floor
    #   return
    # end
    #
    # elevator_floor = @elevator_status[:location]
    #
    # # If elevator is moving down and request floor is below current location, add floor to destinations.
    # if going_down? && (request_floor < elevator_floor)
    #   destination_floor = @destinations[0]
    #   # If request floor is higher than destination floor, insert to make a new destination floor.
    #   if request_floor > destination_floor
    #     @destinations.unshift(request_floor)
    #     return
    #   end
    #
    #   # If request floor is lower than destination floor, insert after destination floor but berfore any lower floor (or end).
    #   # eg, find index of array element starting at [1] that is less than dest floor. If found, insert before. Otherwise, append?
    #
    # end
    #
    # # else if request floor is above current location and elevator is moving up, insert floor into destination.
    # # else
    #
    @elevator_status[:destinations][request_floor] = request[:direction]
    msg "Destinations: #{@elevator_status[:destinations].join(', ')}", Logger::DEBUG
  end
end
