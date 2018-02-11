# A floor of a building.
class Floor
  attr_reader :call_dn, :call_up, :id, :occupants, :waitlist

  @@floor_semaphore = Mutex.new   # Floor objects are subject to multithreaded r/w access.

  def initialize(id)
    @id = id
    @call_dn = false  # the elevator lobby call button, down direction.
    @call_up = false  # the elevator lobby call button, up direction.
    @occupants = []   # persons on a floor (they are not waiting for an elevator).
    @waitlist  = []   # persons in a floor's elevator lobby (they are waiting for an elevator).
  end

  def cancel_call_dn
  @@floor_semaphore.synchronize {
    @call_dn = false
  }
  end

  def cancel_call_up
  @@floor_semaphore.synchronize {
    @call_up = false
  }
  end

  def press_call_dn
    @@floor_semaphore.synchronize {
      @call_dn = true
      msg "Call Down on #{@id}"
    }
  end

  def press_call_up
  @@floor_semaphore.synchronize {
    @call_up = true
    msg "Call Up on #{@id}"
  }
  end

  def enter_floor(occupant)
    insert_occupant(occupant)
    occupant.on_floor(Simulation::time)
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

  def msg(text)
    Simulation::msg "Floor #{@id}: #{text}" if Simulation::debug
  end

end
