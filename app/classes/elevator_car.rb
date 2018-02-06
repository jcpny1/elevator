# An ElevatorCar moves people between floors of a building.
class ElevatorCar

  def initialize(command_q)
    @command_q = command_q
    @direction = 'up'
    @door_status = 'closed'
    @location = 1
    puts 'New Car'
  end

  def run
    while e = @command_q.deq # wait for nil to break loop
      dest = e[:floor].to_i
      puts '<' + e[:cmd] + ' ' + e[:floor] + '>'
      case e[:cmd]
      when 'CALL'
        goto e[:floor].to_i
      when 'GOTO'
        goto e[:floor].to_i
      end
    end
    puts 'New Car' + ' thread done'
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

  def start
    puts '<starting>'
    sleep 0.25
  end

  def stop
    puts '<stopping>'
    sleep 1
  end

  def goto(dest)
    @direction = dest > @location ? 'up' : 'down'
    door_close
    start
    while @location != dest
      sleep 1
      @direction === 'up' ? @location += 1 : @location -= 1
      puts "floor #{@location}"
    end
    stop
    door_open
  end
end
