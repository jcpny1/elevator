# An ElevatorCar moves people between floors of a building.
class Elevator

  DISTANCE_PER_FLOOR  = 12.0
  DISTANCE_PER_SECOND =  4.0
  DISTANCE_UNITS = 'Feet'

  def initialize(id, controller_q, e_status, floors, semaphore)
    @id = id
    @controller_q = controller_q
    @destinations = []                  # floors to visit ordered by visit order.
    @floors = floors                    # read-write by simulation and elevator. Protect with mutex semaphore.
    @semaphore = semaphore
    @passengers = Hash.new { |hash, key| hash[key] = {pickup: 0, discharge: 0} }  # passenger demand by floor.
    @e_status = e_status                # Shared memory status. Read-only in other threads.
    @e_status[:car]       = 'holding'   # car motion.
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
          car_move(@destinations[0] <=> @e_status[:location])
        else
          @e_status[:direction] = '--'
          break if drain_queue
        end
      end
      sleep 0.25
    end
    msg 'done'
  end

private

  # Advance the time the given amount.
  def advance_next_command_time(num)
    @e_status[:time] += num
  end

  # doors will be open 3 seconds per passenger on or off with a minimum open of 3 seconds.
  def car_arrival
    execute_command { car_stop }
    execute_command { door_open }

    discharge = @passengers[@e_status[:location]][:discharge]
    if discharge > 0
      advance_next_command_time(discharge * 3.0)
      @passengers[@e_status[:location]][:discharge] = 0
      msg "discharged #{discharge}"
    end

    # pickup = @passengers[@e_status[:location]][:pickup]
    pickup = []
    @semaphore.synchronize {
      pickup = @floors[@e_status[:location]][:waiters]
      if !pickup.empty?
        advance_next_command_time(pickup.length * 3.0)
      # @passengers[@e_status[:location]][:pickup] = 0
        @floors[@e_status[:location]][:waiters] = []
        msg "picked up #{pickup.length}"
      end
    }

    if (discharge + pickup.length) === 0
      msg 'waiting'
      advance_next_command_time(3.0)
    end
  end

  # Move number of floors indicated. -# = down, +# = up, 0 = arrived.
  def car_move(floors)
    if floors == 0
      execute_command { car_arrival }
      @destinations.shift
    else
      execute_command { car_start }
      @e_status[:direction] = floors < 0 ? 'dn' : 'up'
      @e_status[:location] += floors
      @e_status[:distance] += floors.abs * DISTANCE_PER_FLOOR
      advance_next_command_time(floors.abs * (DISTANCE_PER_FLOOR/DISTANCE_PER_SECOND))
      msg "floor #{@e_status[:location]}"
    end
  end

  def car_start
    if @e_status[:car] === 'holding'
      execute_command { door_close }
      msg 'starting'
      @e_status[:car] = 'moving'
      advance_next_command_time(0.25)
      msg 'started'
    end
  end

  def car_stop
    if @e_status[:car] === 'moving'
      msg "stopping on #{@e_status[:location]}"
      @e_status[:car] = 'holding'
      advance_next_command_time(1.0)
      msg "stopped on #{@e_status[:location]}"
    end
  end

  def door_close
    if @e_status[:door] != 'closed'
      msg 'door closing'
      @e_status[:door] = 'closed'
      advance_next_command_time(2.0)
      msg "door #{@e_status[:door]}"
    end
  end

  def door_open
    if @e_status[:door] != 'open'
      msg 'door opening'
      @e_status[:door] = 'open'
      advance_next_command_time(2.0)
      msg "door #{@e_status[:door]}"
    end
  end

  def execute_command
    sleep 0.25 until Simulation::time >= @e_status[:time]
    yield
# msg "Simulation Time: #{@e_status[:time]}"
  end

  def msg(text)
    puts "Time: %5.2f: Elevator #{@id}: #{text}" % @e_status[:time]
  end

  def process_floor_request(request)
    floor = request[:floor].to_i
    @destinations << floor
    # @passengers[floor][:pickup] += request[:pickup].length
    # request[:pickup].each { |dest_floor| @passengers[dest_floor][:discharge] += 1 }
  end
end
