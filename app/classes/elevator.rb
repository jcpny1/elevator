# An Elevator moves Persons between floors of a building.
class Elevator

  attr_reader :controller_q, :elevator_status

  DISTANCE_PER_FLOOR  = 12.0
  DISTANCE_PER_SECOND =  4.0
  DISTANCE_UNITS = 'Feet'

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
    @destinations = []             # floors to visit ordered by visit order.
    @floors = floors               # on each floor, load from waitlist, discharge to occupant list.

    # Statistics  (multithreaded r/o access. r/w in this thread only.)
    @elevator_status = {}
    @elevator_status[:car]       = 'stopped'   # car motion.
    @elevator_status[:direction] = '--'        # car direction.
    @elevator_status[:distance]  = 0.0         # cumulative distance traveled.
    @elevator_status[:door]      = 'closed'    # door status.
    @elevator_status[:location]  = 1           # floor.
    @elevator_status[:riders]    = {count: 0, weight: 0, occupants: []}  # occupants
    @elevator_status[:time]      = 0.0         # this status effective time.
    msg 'active'
  end

  def run
    drain_queue = false
    while 1
      # Check controller for incoming commands.
      while !@controller_q.empty?
        request = @controller_q.deq
        case request[:cmd]
        when 'CALL', 'GOTO'
          process_floor_request(request)
        when 'END'
          drain_queue = true
        else
          raise "Invalid command: #{request[:cmd]}."
        end
      end
      # Execute next command.
      if Simulation::time >= @elevator_status[:time]
        if !@destinations.empty?
          @elevator_status[:time] = Simulation::time if @elevator_status[:time] === 0.0
          car_move(@destinations.first <=> @elevator_status[:location])
        else
          @elevator_status[:direction] = '--'
          break if drain_queue
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

    floor = @floors[@elevator_status[:location]]
    floor.cancel_call_dn
    floor.cancel_call_up

    # Discharge cycle.
    discharge_count = discharge_passengers
    msg "discharging #{discharge_count}" if discharge_count.positive?

    # Pickup cycle.
    pickup_count = pickup_passengers
    msg "picking up #{pickup_count}" if pickup_count.positive?

    # If neither picking or dropping off, stay open DOOR_WAIT_TIME.
    if (discharge_count + pickup_count).zero?
      msg 'waiting'
      advance_next_command_time(DOOR_WAIT_TIME)
    end
  end

  # Move number of floors indicated. -# = down, +# = up, 0 = arrived.
  def car_move(floor)
    if floor.zero?
      execute_command { car_arrival }
      @destinations.shift
    else
      @elevator_status[:direction] = floor.negative? ? 'dn' : 'up'
      @elevator_status[:location] += floor
      @elevator_status[:distance] += floor.abs * DISTANCE_PER_FLOOR
      execute_command { car_start }
      advance_next_command_time(floor.abs * (DISTANCE_PER_FLOOR/DISTANCE_PER_SECOND))
      msg "floor #{@elevator_status[:location]}"
    end
  end

  def car_start
    if @elevator_status[:car].eql? 'stopped'
      execute_command { door_close }
      msg "starting #{@elevator_status[:direction]}"
      @elevator_status[:car] = 'moving'
      advance_next_command_time(CAR_START)
      execute_command {car_status}
    end
  end

  def car_status
    if @elevator_status[:car].eql? 'stopped'
      msg "#{@elevator_status[:car]} on #{@elevator_status[:location]}"
    else
      msg "#{@elevator_status[:car]} #{@elevator_status[:direction]}"
    end
  end

  def car_stop
    if @elevator_status[:car].eql? 'moving'
      msg "stopping on #{@elevator_status[:location]}"
      @elevator_status[:car] = 'stopped'
      advance_next_command_time(CAR_STOP)
      execute_command {car_status}
    end
  end

  # Discharge riders to destination floor.
  def discharge_passengers
    discharge_count = 0
    floor = @floors[@elevator_status[:location]]
    passengers = @elevator_status[:riders][:occupants].find_all { |occupant| occupant.destination === floor.id }
    passengers.each do |passenger|
      floor.enter_floor(passenger)
      @elevator_status[:riders][:count]  -= 1
      @elevator_status[:riders][:weight] -= passenger.weight
      @elevator_status[:riders][:occupants].delete(passenger)
      advance_next_command_time(DISCHARGE_TIME_PER_PASSENGER)
      discharge_count += 1
    end
    discharge_count
  end

  def door_close
    if !@elevator_status[:door].eql? 'closed'
      msg 'door closing'
      @elevator_status[:door] = 'closed'
      advance_next_command_time(DOOR_CLOSE)
      execute_command {door_status}
    end
  end

  def door_open
    if !@elevator_status[:door].eql? 'open'
      msg 'door opening'
      @elevator_status[:door] = 'open'
      advance_next_command_time(DOOR_OPEN)
      execute_command {door_status}
    end
  end

  def door_status
    msg "door #{@elevator_status[:door]}"
  end

  def execute_command
    sleep LOOP_DELAY until Simulation::time >= @elevator_status[:time]
    yield
  end

  def msg(text)
    Simulation::msg "Elevator #{@id}: #{text}" if Simulation::debug
  end

  # Pickup passengers from floor's wait list.
  def pickup_passengers
    pickup_count = 0
    floor = @floors[@elevator_status[:location]]
    passengers = floor.waitlist
    passengers.each do |passenger|
      next if !passenger.time_to_board
      break if @elevator_status[:riders][:count] == PASSENGER_LIMIT
      break if @elevator_status[:riders][:weight] + passenger.weight > WEIGHT_LIMIT
      floor.leave_waitlist(passenger).on_elevator(Simulation::time)
      @elevator_status[:riders][:count]  += 1
      @elevator_status[:riders][:weight] += passenger.weight
      @elevator_status[:riders][:occupants] << passenger
      @destinations << passenger.destination if !@destinations.include? passenger.destination
      advance_next_command_time(LOAD_TIME_PER_PASSENGER)
      pickup_count += 1
    end
    pickup_count
  end

  def process_floor_request(request)
    floor = request[:floor].to_i
    @destinations << floor
  end
end
