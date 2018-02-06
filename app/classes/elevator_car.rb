# An ElevatorCar moves people between floors of a building.
class ElevatorCar

  FEET_PER_FLOOR = 12

  def initialize(command_q)
    @car_status = 'holding'
    @command_q = command_q
    @destination = []
    @direction = 'up'
    @door_status = 'closed'
    @location = 1
    @feet_traveled = 0
    puts '<New Car active>'
  end

  def run
    drain_queue = false
    while 1
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
          car_start
          @direction = 'up'
          @location += 1
          @feet_traveled += FEET_PER_FLOOR
          sleep 1
          puts "<floor #{@location}>"
        when -1
          car_start
          @direction = 'dn'
          @location -= 1
          @feet_traveled += FEET_PER_FLOOR
          sleep 1
          puts "<floor #{@location}>"
        when 0
          car_stop
          door_open
          sleep 3  # loading time
          @destination.shift
        end
      elsif drain_queue
        door_close
        break;
      else
        sleep 1
      end
    end
    puts "<New Car done. Feet Traveled: #{@feet_traveled}>"
  end

  def car_start
    if @car_status === 'holding'
      door_close
      puts '<starting>'
      @car_status = 'moving'
      sleep 0.25
    end
  end

  def car_stop
    if @car_status === 'moving'
      puts "<stopping on #{@location}>"
      @car_status = 'holding'
      sleep 1
    end
  end

  def door_close
    if @door_status != 'closed'
      puts '<door closing>'
      sleep 2
      @door_status = 'closed'
      puts "<door #{@door_status}>"
    end
  end

  def door_open
    if @door_status != 'open'
      puts '<door opening>'
      sleep 2
      @door_status = 'open'
      puts "<door #{@door_status}>"
    end
  end
end
