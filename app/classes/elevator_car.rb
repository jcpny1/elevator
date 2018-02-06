# An ElevatorCar moves people between floors of a building.
class ElevatorCar
  def initialize(command_q)
    @car_status = 'holding'
    @command_q = command_q
    @destination = []
    @direction = 'up'
    @door_status = 'closed'
    @location = 1
    puts 'New Car'
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
      elsif @car_status === 'holding'
        sleep 1
      end

      if @destination.length > 0
        if @destination[0] > @location
          car_start
          @direction = 'up'
          @location += 1
          sleep 1
          puts "floor #{@location}"
        elsif @destination[0] < @location
          car_start
          @direction = 'dn'
          @location -= 1
          sleep 1
          puts "floor #{@location}"
        else
          car_stop
          door_open
          sleep 3  # loading time
          @destination.shift
        end
      elsif drain_queue
        door_close
        break;
      end
    end

    puts 'New Car' + ' thread done'
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
      puts '<stopping>'
      @car_status = 'holding'
      sleep 1
    end
  end

  def door_close
    if @door_status != 'closed'
      puts '<door closing>'
      sleep 2
      @door_status = 'closed'
      puts 'door ' + @door_status
    end
  end

  def door_open
    if @door_status != 'open'
      puts '<door opening>'
      sleep 2
      @door_status = 'open'
      puts 'door ' + @door_status
    end
  end
end
