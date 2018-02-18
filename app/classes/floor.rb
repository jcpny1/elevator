# A floor of a building.
# Each floor contain an up and a down elevator call button and a wait queue for arriving passengers.
class Floor
  
  # > > > DELETE ALL ATTR_READERS
  attr_reader :call_down, :call_up, :id, :occupants, :waitlist

  LOGGER_MODULE = 'Floor'
  GROUND_FLOOR  = 1     # the floor where occupants enter and exit the building.
  FLOOR_HEIGHT  = 12.0  # the height of each floor.

  @@floor_semaphore = Mutex.new   # Floor objects are subject to multithreaded r/w access.
                                  # Concurrency is improved by having one semaphore for each floor instead of one for all floors.
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
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "cancel call down on #{@id}")
  }
  end

  def cancel_call_up
  @@floor_semaphore.synchronize {
    @call_up = false
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "cancel call up on #{@id}")
  }
  end

  def has_waiters?
    waiters = false
    @@floor_semaphore.synchronize {
      waiters = @waitlist.length.zero?
    }
    waiters
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
    if !@call_down
      msg "call down"
      @call_down = true
    end
  end

  def press_call_up
    if !@call_up
      msg "call up"
      @call_up = true
    end
  end
end
