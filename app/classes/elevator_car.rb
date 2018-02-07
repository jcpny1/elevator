# An ElevatorCar moves people between floors of a building.
class ElevatorCar

  FEET_PER_FLOOR  = 12
  FEET_PER_SECOND =  5

  def initialize(command_q)
    @car_status = 'holding'
    @command_q = command_q
    @destination = []
    @direction = 'up'
    @door_status = 'closed'
    @feet_traveled = 0
    @location = 1
    @next_command_time = Controller::time
    puts '<New Car active>'
  end

  def run
    drain_queue = false
    while 1
      if Controller::time >= @next_command_time
        if @command_q.length > 0
          e = @command_q.deq # wait for nil to break loop
          if e.nil?
            drain_queue = true
          else
            case e[:cmd]
            when 'CALL'
              @destination << e[:floor].to_i
            when 'GOTO'
              @destination << e[:floor].to_i
            end
          end
        end

        if @destination.length > 0
          case @destination[0] <=> @location
          when 1
            car_move(1)
          when -1
            car_move(-1)
          when 0
            car_arrive
            @destination.shift
          end
        elsif drain_queue && @car_status === 'holding'
          door_close
          break;
        else
          @next_command_time = Controller::time  # ready for next command
        end
      end
      sleep 0.25
    end
    puts "<New Car done. Distance Traveled: #{@feet_traveled} feet>"
  end

private

  def car_arrive
    car_stop
    door_open
    @next_command_time += 3  # loading
  end

  def car_move(floors)
    car_start
    @direction = floors < 0 ? 'dn' : 'up'
    @location += floors
    @feet_traveled += floors.abs * FEET_PER_FLOOR
    @next_command_time += floors.abs * FEET_PER_FLOOR/FEET_PER_SECOND
    puts "<floor #{@location}>"
  end

  def car_start
    if @car_status === 'holding'
      door_close
      puts '<starting>'
      @car_status = 'moving'
      @next_command_time += 0.25
    end
  end

  def car_stop
    if @car_status === 'moving'
      puts "<stopping on #{@location}>"
puts "Simulation Time: #{Controller::time}"
      @car_status = 'holding'
      @next_command_time += 1
    end
  end

  def door_close
    if @door_status != 'closed'
      puts '<door closing>'
      @next_command_time += 2
      @door_status = 'closed'
      puts "<door #{@door_status}>"
    end
  end

  def door_open
    if @door_status != 'open'
      puts '<door opening>'
      @next_command_time += 2
      @door_status = 'open'
      puts "<door #{@door_status}>"
    end
  end
end
