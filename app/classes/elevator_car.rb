require 'pry'
# An ElevatorCar moves people between floors of a building.
class ElevatorCar

  DISTANCE_PER_FLOOR  = 12.0
  DISTANCE_PER_SECOND =  4.0
  DISTANCE_UNITS = 'Feet'

  def initialize(id, controller_q)
    @car_status = 'holding'
    @controller_q = controller_q
    @current_direction = ''
    @current_location = 1
    @destinations = []  # floors to visit ordered by visit order.
    @distance_traveled = 0.0
    @door_status = 'closed'
    @elevator_name = "Elevator #{id}"
    @next_command_time = Controller::time
    @passengers = Hash.new { |hash, key| hash[key] = {pickup: 0, discharge: 0} }
    msg 'active'
  end

  def run
    drain_queue = false
    while 1
      # Check controller for incoming commands.
      if @controller_q.length > 0
        e = @controller_q.deq
        case e[:cmd]
        when 'CALL', 'GOTO'
          floor = e[:floor].to_i
          @destinations << floor
          @passengers[floor][:pickup] += e[:pickup].length
          e[:pickup].each { |dest_floor| @passengers[dest_floor][:discharge] += 1 }
        when Controller::END_OF_SIMULATION
          drain_queue = true
        else
          msg '***Unknown command***'
        end
      end
      # Execute next command.
      if Controller::time >= @next_command_time
        if @destinations.length > 0
          car_move(@destinations[0] <=> @current_location)
        elsif drain_queue && @car_status === 'holding'
          break;
        end
      end
      sleep 0.25
    end
    msg "done. distance traveled: #{@distance_traveled} #{DISTANCE_UNITS}"
  end

private

  # Advance the time the given amount.
  def advance_next_command_time(num)
    @next_command_time += num
  end

  # doors will be open 3 seconds per passenger on or off with a minimum open of 3 seconds.
  def car_arrival
    execute_command { car_stop }
    execute_command { door_open }

    discharge = @passengers[@current_location][:discharge]
    if discharge > 0
      advance_next_command_time(discharge * 3.0)
      @passengers[@current_location][:discharge] = 0
      msg "discharged #{discharge}"
    end

    pickup = @passengers[@current_location][:pickup]
    if pickup > 0
      advance_next_command_time(pickup * 3.0)
      @passengers[@current_location][:pickup] = 0
      msg "picked up #{pickup}"
    end

    if (discharge + pickup) === 0
      msg 'waiting'
      advance_next_command_time(3.0)
    end
  end

  # Move number of floors indicated. - = down, + = up, 0 = arrived.
  def car_move(floors)
    if floors == 0
      execute_command { car_arrival }
      @destinations.shift
    else
      execute_command { car_start }
      @current_direction = floors < 0 ? 'dn' : 'up'
      @current_location += floors
      @distance_traveled += floors.abs * DISTANCE_PER_FLOOR
      advance_next_command_time(floors.abs * (DISTANCE_PER_FLOOR/DISTANCE_PER_SECOND))
      msg "floor #{@current_location}"
    end
  end

  def car_start
    if @car_status === 'holding'
      execute_command { door_close }
      msg 'starting'
      @car_status = 'moving'
      advance_next_command_time(0.25)
      msg 'started'
    end
  end

  def car_stop
    if @car_status === 'moving'
      msg "stopping on #{@current_location}"
      @car_status = 'holding'
      advance_next_command_time(1.0)
      msg "stopped on #{@current_location}"
    end
  end

  def door_close
    if @door_status != 'closed'
      msg 'door closing'
      @door_status = 'closed'
      advance_next_command_time(2.0)
      msg "door #{@door_status}"
    end
  end

  def door_open
    if @door_status != 'open'
      msg 'door opening'
      @door_status = 'open'
      advance_next_command_time(2.0)
      msg "door #{@door_status}"
    end
  end

  def execute_command
    sleep 0.25 until Controller::time >= @next_command_time
    yield
# msg "Simulation Time: #{@next_command_time}"
  end

  def msg(text)
    puts "Time: %5.2f: #{@elevator_name}: #{text}" % @next_command_time
  end
end
