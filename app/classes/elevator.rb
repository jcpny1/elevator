# An ElevatorCar moves people between floors of a building.
class Elevator

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
  LOOP_DELAY = 0.125  # seconds.

  PASSENGER_LIMIT = 10
  WEIGHT_LIMIT = 2000

  def initialize(id, controller_q, e_status, floors, semaphore)
    @id = id
    @controller_q = controller_q
    @destinations = []                  # floors to visit ordered by visit order.
    @floors = floors                    # read-write by simulation and elevator. Protect with mutex semaphore.
    @riders = {count: 0, weight: 0, persons: []}  # elevator occupants
    @semaphore = semaphore
    @passengers = Hash.new { |hash, key| hash[key] = {pickup: 0, discharge: 0} }  # passenger demand by floor.
    @e_status = e_status                # Shared memory status. Read-only in other threads.
    @e_status[:car]       = 'stopped'   # car motion.
    @e_status[:direction] = '--'        # car direction.
    @e_status[:distance]  = 0.0         # cumulative distance traveled.
    @e_status[:door]      = 'closed'    # door status.
    @e_status[:location]  = 1           # floor.
    @e_status[:time]      = 0.0         # this status effective time.
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
      if Simulation::time >= @e_status[:time]
        if !@destinations.empty?
          @e_status[:time] = Simulation::time if @e_status[:time] === 0.0
          car_move(@destinations.first <=> @e_status[:location])
        else
          @e_status[:direction] = '--'
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
    @e_status[:time] += num
  end

  # Execute arrival procedures.
  def car_arrival
    execute_command { car_stop }
    execute_command { door_open }

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
  def car_move(floors)
    if floors.zero?
      execute_command { car_arrival }
      @destinations.shift
    else
      @e_status[:direction] = floors.negative? ? 'dn' : 'up'
      @e_status[:location] += floors
      @e_status[:distance] += floors.abs * DISTANCE_PER_FLOOR
      execute_command { car_start }
      advance_next_command_time(floors.abs * (DISTANCE_PER_FLOOR/DISTANCE_PER_SECOND))
      msg "floor #{@e_status[:location]}"
    end
  end

  def car_start
    if @e_status[:car].eql? 'stopped'
      execute_command { door_close }
      msg "starting #{@e_status[:direction]}"
      @e_status[:car] = 'moving'
      advance_next_command_time(CAR_START)
      execute_command {car_status}
    end
  end

  def car_status
    if @e_status[:car].eql? 'stopped'
      msg "#{@e_status[:car]} on #{@e_status[:location]}"
    else
      msg "#{@e_status[:car]} #{@e_status[:direction]}"
    end
  end

  def car_stop
    if @e_status[:car].eql? 'moving'
      msg "stopping on #{@e_status[:location]}"
      @e_status[:car] = 'stopped'
      advance_next_command_time(CAR_STOP)
      execute_command {car_status}
    end
  end

  # Discharge riders to destination floor.
  def discharge_passengers
    discharge_count = 0
    @riders[:persons].delete_if do |person|
      next if !person.destination.eql? @e_status[:location]
      @semaphore.synchronize {
        @floors[@e_status[:location]][:occupants] << person
      }
      person.on_floor(Simulation::time)
      @riders[:count]  -= 1
      @riders[:weight] -= person.weight
      advance_next_command_time(DISCHARGE_TIME_PER_PASSENGER)
      discharge_count += 1
      true
    end
    discharge_count
  end

  def door_close
    if !@e_status[:door].eql? 'closed'
      msg 'door closing'
      @e_status[:door] = 'closed'
      advance_next_command_time(DOOR_CLOSE)
      execute_command {door_status}
    end
  end

  def door_open
    if !@e_status[:door].eql? 'open'
      msg 'door opening'
      @e_status[:door] = 'open'
      advance_next_command_time(DOOR_OPEN)
      execute_command {door_status}
    end
  end

  def door_status
    msg "door #{@e_status[:door]}"
  end

  def execute_command
    sleep LOOP_DELAY until Simulation::time >= @e_status[:time]
    yield
  end

  def msg(text)
    Simulation::msg "Elevator #{@id}: #{text}" if Simulation::debug
  end

  # Pickup passengers from floor's wait list.
  def pickup_passengers
    pickup_count = 0
    @semaphore.synchronize {
      waiters = @floors[@e_status[:location]][:waiters]
      waiters.delete_if do |person|
        break if @riders[:count] == PASSENGER_LIMIT
        break if @riders[:weight] + person.weight > WEIGHT_LIMIT
        @riders[:persons] << person
        person.on_elevator(Simulation::time)
        @riders[:count]  += 1
        @riders[:weight] += person.weight
        advance_next_command_time(LOAD_TIME_PER_PASSENGER)
        pickup_count += 1
        @destinations << person.destination if !@destinations.include? person.destination
        true
      end
    }
    pickup_count
  end

  def process_floor_request(request)
    floor = request[:floor].to_i
    @destinations << floor
  end
end
