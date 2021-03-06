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
    @id           = id    # Floor Id.
    @call_down    = false # elevator lobby call down button activation status.
    @call_up      = false # elevator lobby call up button activation status.
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

  # Turn off elevator lobby call down button.
  def cancel_call_down
  @@floor_semaphore.synchronize {
    if @call_down
      @call_down = false
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "cancel call down on #{@id}")
    end
  }
  end

  # Turn off elevator lobby call up button.
  def cancel_call_up
  @@floor_semaphore.synchronize {
    if @call_up
      @call_up = false
      Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "cancel call up on #{@id}")
    end
  }
  end

  # Does this floor have elevator lobby waiters?
  def has_waiters?
    waiters = 0
    @@floor_semaphore.synchronize {
      waiters = @waitlist.length
    }
    !waiters.zero?
  end

  # Return height of floor.
  def self.height
    FLOOR_HEIGHT
  end

  # Take occupant off elevator lobby waitlist if supplied code block returns true.
  def leave_waitlist
    @@floor_semaphore.synchronize {
      old_occupant_count = @occupants.length
      old_waitlist_count = @waitlist.length
      @waitlist.delete_if { |passenger| yield(passenger) }
      msg "occupant list now: #{@occupants.length}", Logger::DEBUG if @occupants.length != old_occupant_count
      msg "waitlist now: #{@waitlist.length}", Logger::DEBUG if @waitlist.length != old_waitlist_count
    }
  end

  # Remove occupant from floor list and place on wait list if it is time for occupant to board.
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

  # Place occupant on elevator lobby wait list.
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
      occupant.on_waitlist(occupant.lobby_time, @id)
      msg "occupant list now: #{@occupants.length}", Logger::DEBUG
      msg "waitlist now: #{@waitlist.length}", Logger::DEBUG
  end

  def msg(text_msg, debug_level = Logger::INFO)
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, debug_level, text_msg)
  end

  # Activate elevator lobby call down button.
  def press_call_down
    if !@call_down
      msg "call down"
      @call_down = true
    end
  end

  # Activate elevator lobby call up button.
  def press_call_up
    if !@call_up
      msg "call up"
      @call_up = true
    end
  end
end
