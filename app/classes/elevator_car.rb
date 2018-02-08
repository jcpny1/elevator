# An ElevatorCar moves people between floors of a building.
class ElevatorCar

  FEET_PER_FLOOR  = 12.0
  FEET_PER_SECOND =  4.0

  def initialize(name, controller_q)
    @car_status = 'holding'
    @controller_q = controller_q
    @current_direction = ''
    @current_location = 1
    @destinations = []  # floors to visit ordered by visit order.
    @door_status = 'closed'
    @feet_traveled = 0.0
    @next_command_time = Controller::time
    @passengers = Hash.new { |hash, key| hash[key] = {pickup: 0, discharge: 0} }
    puts '<New Car active>'
  end

  def run
    drain_queue = false
    while 1
      # Check controller for incoming commands.
      if @controller_q.length > 0
        e = @controller_q.deq # wait for nil to break loop
        if e.nil?
          drain_queue = true
        else
          case e[:cmd]
          when 'CALL', 'GOTO'
            floor = e[:floor].to_i
            @destinations << floor
            @passengers[floor][:pickup] += e[:pickup].length
            e[:pickup].each { |dest_floor| @passengers[dest_floor][:discharge] += 1 }
          else
            puts '***Unknown command***'
          end
        end
      end
      # Execute next command.
      if Controller::time >= @next_command_time
        if @destinations.length > 0
          car_move(@destinations[0] <=> @current_location)
        elsif drain_queue && @car_status === 'holding'
          door_close
          break;
        else
          advance_next_command_time(0)  # ready for next command
        end
      end
      sleep 0.25
    end
    puts "<New Car done. Distance Traveled: #{@feet_traveled} feet>"
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
puts "<Discharge #{@passengers[@current_location][:discharge]}"
puts "<Pickup    #{@passengers[@current_location][:pickup]}"
    passenger_time = (@passengers[@current_location][:discharge] * 3.0) + (@passengers[@current_location][:pickup] * 3.0)
    @passengers[@current_location][:discharge] = 0
    @passengers[@current_location][:pickup]    = 0
    advance_next_command_time(passenger_time > 0.0 ? passenger_time : 3.0)
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
      @feet_traveled += floors.abs * FEET_PER_FLOOR
      puts "<floor #{@current_location}>"
      advance_next_command_time(floors.abs * (FEET_PER_FLOOR/FEET_PER_SECOND))
    end
  end

  def car_start
    if @car_status === 'holding'
      execute_command { door_close }
      puts '<starting>'
      @car_status = 'moving'
      advance_next_command_time(0.25)
    end
  end

  def car_stop
    if @car_status === 'moving'
      puts "<stopping>"
      @car_status = 'holding'
      puts "<stopped on #{@current_location}>"
      advance_next_command_time(1.0)
    end
  end

  def door_close
    if @door_status != 'closed'
      puts '<door closing>'
      @door_status = 'closed'
      puts "<door #{@door_status}>"
      advance_next_command_time(2.0)
    end
  end

  def door_open
    if @door_status != 'open'
      puts '<door opening>'
      @door_status = 'open'
      puts "<door #{@door_status}>"
      advance_next_command_time(2.0)
    end
  end

  def execute_command
    sleep 0.25 until Controller::time >= @next_command_time
    yield
    puts "Simulation Time: #{@next_command_time}"
  end
end
