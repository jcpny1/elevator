# An ElevatorCar moves people between floors of a building.
class ElevatorCar

  def initialize
    @direction = 'up'
    @door_status = 'closed'
    @location = 1
  end

  def door_close
    if @door_status != 'closed'
      puts '<door closing>'
      sleep 2
      @door_status = 'closed'
    end
    puts 'door ' + @door_status
  end

  def door_open
    if @door_status != 'open'
      puts '<door opening>'
      sleep 2
      @door_status = 'open'
    end
    puts 'door ' + @door_status
  end

  def goto(dest)
    @direction = dest > @location ? 'up' : 'down'
    door_close
    while @location != dest
      sleep 1
      @direction === 'up' ? @location += 1 : @location -= 1
      puts "floor #{@location}"
    end
    door_open
  end
end
