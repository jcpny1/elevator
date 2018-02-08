require 'pry'
# An ElevatorCar moves people between floors of a building.
class ElevatorCar

  DISTANCE_PER_FLOOR  = 12.0
  DISTANCE_PER_SECOND =  4.0
  DISTANCE_UNITS = 'Feet'

  def initialize(id, controller_q, e_status)
    @id = id
    @controller_q = controller_q
    @destinations = []  # floors to visit ordered by visit order.
    @passengers = Hash.new { |hash, key| hash[key] = {pickup: 0, discharge: 0} }
    @e_status = e_status
    @e_status[:car]       = 'holding'
    @e_status[:direction] = '--'
    @e_status[:distance]  = 0.0
    @e_status[:door]      = 'closed'
    @e_status[:location]  = 1
    @e_status[:time]      = Controller::time
    msg 'active'
  end

  def run
    drain_queue = false
    while 1
      # Check controller for incoming commands.
      if @controller_q.length > 0
        request = @controller_q.deq
        case request[:cmd]
        when 'CALL', 'GOTO'
          process_floor_request(request)
        when Controller::END_OF_SIMULATION
          drain_queue = true
        else
          msg '***Unknown command***'
        end
      end
      # Execute next command.
      if Controller::time >= @e_status[:time]
        if @destinations.length > 0
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

    pickup = @passengers[@e_status[:location]][:pickup]
    if pickup > 0
      advance_next_command_time(pickup * 3.0)
      @passengers[@e_status[:location]][:pickup] = 0
      msg "picked up #{pickup}"
    end

    if (discharge + pickup) === 0
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
    sleep 0.25 until Controller::time >= @e_status[:time]
    yield
# msg "Simulation Time: #{@e_status[:time]}"
  end

  def msg(text)
    puts "Time: %5.2f: Elevator #{@id}: #{text}" % @e_status[:time]
  end

  def process_floor_request(request)
    floor = request[:floor].to_i
    @destinations << floor
    @passengers[floor][:pickup] += request[:pickup].length
    request[:pickup].each { |dest_floor| @passengers[dest_floor][:discharge] += 1 }
  end
end
