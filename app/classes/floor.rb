# A floor of a building.
# Each floor contain an up and a down elevator call button and a wait queue for arriving passengers.
class Floor
  LOGGER_MODULE = 'Floor'
  GROUND_FLOOR  = 1     # the floor where occupants enter and exit the building.
  FLOOR_HEIGHT  = 12.0  # the height of each floor.


# > > > DELETE ALL ATTR_READERS

  @@floor_semaphore = Mutex.new   # Floor objects are subject to multithreaded r/w access.
                                  # Concurrency is improved by having one semaphore for each floor instead of one for all floors.
  attr_reader :call_down, :call_up, :id, :occupants, :waitlist

  def initialize(id)
    @id = id
    @call_down = false  # the elevator lobby call down button activation status.
    @call_up = false    # the elevator lobby call up button activation status.
    @controller_q = nil # command interface to the elevator Controller.
    @occupants = []     # persons on a floor that are not waiting for an elevator).
    @waitlist  = []     # persons on a floor that are waiting for an elevator.
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
  end

  def accept_occupant(occupant)
    @@floor_semaphore.synchronize {
      @occupants << occupant
      msg "Occupant list now: #{@occupants.length}", Logger::DEBUG
    }
  end

  def cancel_call_down
  @@floor_semaphore.synchronize {
    @call_down = false
  }
  end

  def cancel_call_up
  @@floor_semaphore.synchronize {
    @call_up = false
  }
  end

  def controller_q=(q)
    @controller_q = q
  end

  def self.height
    FLOOR_HEIGHT
  end

  def enter_waitlist(occupant)
    @@floor_semaphore.synchronize {
      @waitlist << @occupants.delete(occupant)
      case occupant.destination <=> @id
      when -1
        press_call_down
      when 0
        raise "Invalid destination: #{occupant.destination}"
      when 1
        press_call_up
      end
      occupant.on_waitlist(occupant.enq_time)
      msg "Occupant list now: #{@occupants.length}", Logger::DEBUG
      msg "Waitlist now: #{@waitlist.length}", Logger::DEBUG
    }
  end

  def leave_waitlist(occupant)
    occ = nil
    @@floor_semaphore.synchronize {
      occ = @waitlist.delete(occupant)
      msg "Waitlist now: #{@waitlist.length}", Logger::DEBUG
    }
    occ
  end

  def waitlist_length
    @@floor_semaphore.synchronize {
      @waitlist.length
    }
  end

private

  def msg(text_msg, debug_level = Logger::INFO)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, debug_level, text_msg)
  end

  def press_call_down
    @call_down = true
    @controller_q << {time: Simulator::time, cmd: 'CALL', floor: @id, direction: 'dn'}
    msg "Call Down"
  end

  def press_call_up
    @call_up = true
    @controller_q << {time: Simulator::time, cmd: 'CALL', floor: @id, direction: 'up'}
    msg "Call Up"
  end
end
