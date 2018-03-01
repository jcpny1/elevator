# The Controller send commands to elevators.
# The Controller can view each elevator's scheduled stops and each floor's call button status.
# The Controller assigns elevators to service floor call requests.
# The Controller commands an elevator to move when a movement is determined to be necessary.
class Controller

  LOGGER_MODULE = 'Controller'  # for console logger.
  LOOP_DELAY    = 0.010         # (seconds) - sleep delay in controller loop.

  def initialize(elevators, floors, logic)
    @id         = 0          # Controller Id.
    @elevators  = elevators  # Elevators controlled by this Controller.
    @floors     = floors     # Floors services by these elevators. For now, assume all elevators service all floors.
    @logic      = logic      # Elevator control logic name.
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
  end

  # Main logic:
  #  1. Create an elevator request, if possible.
  #  2. Goto step 1.
  def run
    while true
      create_requests.each do |request|
        Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, request)
        elevator = @elevators[request[:elevator_idx]]
        elevator[:car].command_q << request
        elevator[:car].status = 'executing'
      end
      sleep LOOP_DELAY
    end
  end

private

  # Create elevator movement requests given current floor and elevator states.
  # Return elevator command, or nil if nothing to do.
  def create_requests
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG_2, 'create request')
    requests = []
    ruleno = ''
    if @logic == 'SCAN'
      requests << do_scan_logic
    else
      # 2. If waiting elevator with riders then
      elevator = elevator_waiting_with_riders
      if !elevator.nil?
        if @logic == 'FCFS'
          # 2A. Send elevator to destination of earliest-boarded rider.
          destination = elevator[:car].occupants.first.destination
          ruleno = '2A'
        elsif @logic == 'SSTF'
          # 2B. Send elevator to closest scheduled stop for this elevator in any direction.
          destination = next_stop(elevator[:car], elevator[:car].stops, elevator[:car].floor_idx, 'any' )
          ruleno = '2B'
        elsif @logic == 'L-SCAN'
          # 2C. Send elevator to closest scheduled stop for this elevator in direction of travel.
          destination = next_stop(elevator[:car], elevator[:car].stops, elevator[:car].floor_idx, nil )
          ruleno = '2C'
        else
          raise "Invalid logic: #{@logic}"
        end
        requests << {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: destination, rule: ruleno} if !destination.nil?
      else
        # 3. If elevator has no riders but is waiting at a floor with waiters then
        elevator = elevator_waiting_at_floor_with_waiters
        if !elevator.nil?
          # 3A. Resend elevator to that same floor to activate departure logic.
          floor_idx = elevator[:car].floor_idx
          requests << {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: floor_idx, rule: '3A'}
        else
          # 4. If any waiting elevator,
          elevator = elevator_waiting
          if !elevator.nil?
            if @logic == 'FCFS'
              # 4A. Find floor with earliest waiter.
              floor = floor_with_earliest_waiter
              requests << {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: floor.id, rule: '4A'} if !floor.nil?
            elsif @logic == 'SSTF'
              # 4B. Find closest floor with waiters in either direction.
              floor = floor_with_nearest_waiter(elevator[:car].floor_idx)
              requests << {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: floor.id, rule: '4B'} if !floor.nil?
            end
          end
        end
      end
    end
    requests
  end

  # Send waiting elevator to next floor in direction of travel. If at end of travel, reverse direction.
  # Return elevator request command.
  def do_scan_logic
    request = nil
    elevator = elevator_waiting
    if !elevator.nil?
      if elevator[:car].going_up?
        destination = elevator[:car].floor_idx + 1
        if destination == @floors.length
          destination = elevator[:car].floor_idx - 1
        end
      else
        destination = elevator[:car].floor_idx - 1
        if destination == 0
          destination = elevator[:car].floor_idx + 1
        end
      end
      request = {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: destination, rule: 'SCAN', file: __FILE__, line: __LINE__}
    end
    request
  end

  # Return a waiting elevator.
  # Optionally, on a specific floor.
  def elevator_waiting(floor_id=nil)
    if floor_id.nil?
      @elevators.find { |e| e[:car].waiting? }
    else
      @elevators.find { |e| e[:car].waiting? && e[:car].floor_idx == floor_id }
    end
  end

  # Return a waiting elevator on a floor with occupants waiting in the elevator lobby.
  def elevator_waiting_at_floor_with_waiters
    @elevators.find { |e| e[:car].waiting? && @floors[e[:car].floor_idx].has_waiters? }
  end

  # Return a waiting elevator that has riders on board.
  def elevator_waiting_with_riders
    @elevators.find { |e| e[:car].waiting? && e[:car].has_riders? }
  end

  # Return floor that has the earliest waiter.
  def floor_with_earliest_waiter
    earliest_floor = nil
    earliest_wait_time = Simulator::time + 1.0
    @floors.find_all { |f| f.has_waiters? }.each do |floor|
      if floor.waitlist[0].on_waitlist_time < earliest_wait_time
        earliest_wait_time = floor.waitlist[0].on_waitlist_time
        earliest_floor = floor
      end
    end
    earliest_floor
  end

  # Return floor of waiter nearest to given floor in any direction.
  def floor_with_nearest_waiter(floor_idx)
    waiter_floors = @floors.find_all { |f| f.has_waiters? }.sort { |floor1, floor2| floor1.id <=> floor2.id }
    down_floor_idx = waiter_floors.rindex { |floor| floor.id < floor_idx }
    down_floor = down_floor_idx.nil? ? nil : waiter_floors[down_floor_idx]
    up_floor_idx = waiter_floors.index { |floor| floor.id > floor_idx }
    up_floor = up_floor_idx.nil? ? nil : waiter_floors[up_floor_idx]
    if down_floor.nil?
      up_floor
    elsif up_floor.nil?
      down_floor
    else # we have waiters above and below.
      # TODO for now, we'll bias equidistant waiters to the up direction. we may want to adjust that with time-of-day or number of riders optimizations.
      down_floor_diff = floor_idx - down_floor.id
      up_floor_diff = up_floor.id - floor_idx
      down_floor_diff < up_floor_diff ? down_floor : up_floor
    end

  end

  def logic_sstf(request)
    elevator = nil
    request_floor = request[:floor]
    diffs = []
    # Measure distance to request floor from each elevator.
    @elevators.each do |e|
      if request_floor > e[:car].floor_idx
        if e[:car].going_down?
          diffs << @num_floors + 1  # don't consider this elevator.
        else  # elevator is going up or is stationery.
          diffs << request_floor - e[:car].floor_idx
        end
      elsif request_floor < e[:car].floor_idx
        if e[:car].going_up?
          diffs << @num_floors + 1  # don't consider this elevator.
        else  # elevator is going down or is stationery.
          diffs << e[:car].floor_idx - request_floor
        end
      elsif e[:car].stationary?  # and is on call floor already.
        diffs << 0
      else  # car is on floor but is moving away.
        diffs << @num_floors + 1  # don't consider this elevator.
      end
    end
    smallest_diff = @num_floors + 1
    elevator_num = -1
    diffs.each_with_index do |diff, i|
      if diff < smallest_diff
        smallest_diff = diff if diff < smallest_diff
        elevator_num = i
      end
    end

    if elevator_num == -1  # no elevator found.
      elevator = logic_fcfs(request)
    else
      elevator = @elevators[elevator_num]
    end
    elevator
  end

  # Return nearest scheduled stop to current location.
  def nearest_stop(stops, floor_idx)
    down_stop = next_stop_down(stops, floor_idx)
    up_stop = next_stop_up(stops, floor_idx)

    if down_stop.nil?
      up_stop
    elsif up_stop.nil?
      down_stop
    else # we have stops going up and going down.
      # TODO for now, we'll bias equidistant stops to the up direction. we may want to adjust that with time-of-day or number of riders optimizations.
      dn_stop_diff = floor_idx - dn_stop
      up_stop_diff = up_stop - floor_idx
      dn_stop_diff < up_stop_diff ? dn_stop : up_stop
    end
  end

  # Determines elevator's next stop.
  # When direction = 'any', return nearest stop in any direction.
  # Otherwise, return nearest stop in direction of elevator travel.
  # If no stop in direction of travel, return stop in opposite direction of travel.
  # If elevator is stationary, return closest stop in either direction.
  def next_stop(elevator, stops, floor_idx, direction)

   if direction == 'any'
     return nearest_stop(stops, floor_idx)
   end

   if elevator.going_down?
     stop = next_stop_down(stops, floor_idx)
     return stop if !stop.nil?
   end

   if elevator.going_up?
     stop = next_stop_up(stops, floor_idx)
     return stop if !stop.nil?
   end

   return nearest_stop(stops, floor_idx)
  end

  # Return elevator's next stop in the down direction.
  def next_stop_down(stops, floor_idx)
   stops.slice(0...floor_idx).rindex { |stop| stop }
  end

  # Return elevator's next stop in the up direction.
  def next_stop_up(stops, floor_idx)
   stop = stops.slice((floor_idx + 1)...stops.length).index { |s| s }
   stop += (floor_idx + 1) if !stop.nil?
  end
end
