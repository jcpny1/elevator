# A floor of a building.
class Floor
  attr_reader :call_down, :call_up, :id, :occupants, :waitlist

  LOGGER_MODULE = 'Floor'

  @@floor_semaphore = Mutex.new   # Floor objects are subject to multithreaded r/w access.
                                  # Concurrency is improved by having one semaphore for each floor instead of one for all floors.
  def initialize(id)
    @id = id
    @call_down = false  # the elevator lobby call button, down direction.
    @call_up = false  # the elevator lobby call button, up direction.
    @occupants = []   # persons on a floor (they are not waiting for an elevator).
    @waitlist  = []   # persons in a floor's elevator lobby (they are waiting for an elevator).
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

  def press_call_down
    @@floor_semaphore.synchronize {
      @call_down = true
      msg "Call Down"
    }
  end

  def press_call_up
  @@floor_semaphore.synchronize {
    @call_up = true
    msg "Call Up"
  }
  end

  def enter_floor(occupant)
    insert_occupant(occupant)
    occupant.on_floor(Simulator::time)
  end

  def enter_waitlist(occupant)
    @@floor_semaphore.synchronize {
      @waitlist << @occupants.delete(occupant)
      occupant.on_waitlist(occupant.enq_time)
    }
  end

  def insert_occupant(occupant)
    @@floor_semaphore.synchronize {
      @occupants << occupant
    }
  end

  def leave_waitlist(occupant)
    occ = nil
    @@floor_semaphore.synchronize {
      occ = @waitlist.delete(occupant)
    }
    occ
  end

private

  def msg(text_msg, debug_level = Logger::INFO)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, debug_level, text_msg)
  end
end
