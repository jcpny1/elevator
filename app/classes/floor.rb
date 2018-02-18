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
    @id           = id    # Floor id
    @call_down    = false # the elevator lobby call down button activation status.
    @call_up      = false # the elevator lobby call up button activation status.
    @occupants    = []    # persons on a floor that are not waiting for an elevator).
    @waitlist     = []    # persons on a floor that are waiting for an elevator.
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
  end

  def accept_occupant(occupant)
    @@floor_semaphore.synchronize {
      @occupants << occupant
      msg "occupant list now: #{@occupants.length}", Logger::DEBUG
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

  def self.height
    FLOOR_HEIGHT
  end

  def leave_waitlist
    @@floor_semaphore.synchronize {
      old_occupant_count = @occupants.length
      old_waitlist_count = @waitlist.length
      @waitlist.delete_if { |passenger| yield(passenger) }
      msg "occupant list now: #{@occupants.length}", Logger::DEBUG if @occupants.length != old_occupant_count
      msg "waitlist now: #{@waitlist.length}", Logger::DEBUG if @waitlist.length != old_waitlist_count
    }
  end

  def update_wait_queue
    @@floor_semaphore.synchronize {
      @occupants.delete_if do |occupant|
        ret_stat = false
        if occupant.time_to_board?
          enter_waitlist(occupant)
          ret_stat = true
        end
        ret_stat
      end
    }
  end

  def waitlist_length
    @@floor_semaphore.synchronize {
      @waitlist.length
    }
  end

private

  def enter_waitlist(occupant)
      @waitlist << occupant
      case occupant.destination <=> @id
      when -1
        press_call_down
      when 0
        raise "Invalid destination: #{occupant.destination}"
      when 1
        press_call_up
      end
      occupant.on_waitlist(occupant.enq_time)
      msg "occupant list now: #{@occupants.length}", Logger::DEBUG
      msg "waitlist now: #{@waitlist.length}", Logger::DEBUG
  end

  def msg(text_msg, debug_level = Logger::INFO)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, debug_level, text_msg)
  end

  def press_call_down
    @call_down = true
    msg "call down"
  end

  def press_call_up
    @call_up = true
    msg "call up"
  end
end
