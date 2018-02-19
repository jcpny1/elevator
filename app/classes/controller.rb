# The Controller send commands to elevators.
# The Controller can view each elevator and call button status.
# The Controller monitors every call button status and assigns elevators to service call requests.
# The Controller monitors every elevator status and commands the elevator to move when a movement is determined to be necessary.
class Controller

  LOGGER_MODULE = 'Controller'  # for console logger.
  LOOP_DELAY    = 0.01          # (seconds) - sleep delay in controller loop.

  def initialize(elevators, floors, logic)
    @id         = 0          # Controller id.
    @elevators  = elevators  # Elevators controlled by this Controller.
    @floors     = floors     # Floors services by these elevators. For now, assume all elevators service all floors.
    @logic      = logic      # Elevator control logic name.
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
  end

  def run
    while true
      request = create_request
      if !request.nil?
        Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, request)
        elevator = @elevators[request[:elevator_idx]]
        elevator[:car].command_q << request
        elevator[:car].status = 'moving'
      end
      sleep LOOP_DELAY
    end
  end

private

  # Create elevator movement requests given current floor and elevator states.
  # Returns elevator command, or nil if nothing to do.
  def create_request
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG_2, 'create request')
    request = nil

### USE ELEVATOR'S STOP[_BUTTONS] ARRAY

    # 1. If waiting elevator with riders then
    #      Send elevator to closest elevator stop in direction of travel.
    elevator = elevator_waiting_with_riders
    if !elevator.nil?
      if fcfs?
        rider = elevator[:car].elevator_status[:riders][:occupants][0]
        destination = rider.destination
      else
        destination = elevator[:car].next_stop
      end
      request = {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: destination} if !destination.nil?
    else
      # 2. If elevator waiting at floor with waiters, take destination of first waiter and send elevator there.


      elevator = elavator_waiting_at_floor_with_waiters
      if !elevator.nil?
        current_floor_idx = elevator[:car].current_floor
        destination_floor_idx = @floors[current_floor_idx].waitlist[0].destination
        request = {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: destination_floor_idx}
      else
        # 3. If floor with a waiter then
        #      If waiting elevator then
        #        Send elevator to waiter's floor.
        floor = floor_with_waiter
        elevator = elevator_waiting
        if !floor.nil? && !elevator.nil?
          request = {time: Simulator::time, elevator_idx: elevator[:car].id, cmd: 'GOTO', floor_idx: floor.id}
        end
      end
    end
    request
  end

  # Using First Come, First Served logic?
  def fcfs?
    @logic == 'FCFS'
  end

  def floor_with_waiter
    @floors.find { |f| !f.has_waiters? }
  end

  def elevator_waiting(floor_id=nil)
    if floor_id.nil?
      @elevators.find { |e| e[:car].waiting? }
    else
      @elevators.find { |e| e[:car].waiting? && e[:car].current_floor == floor_id }
    end
  end

  def elavator_waiting_at_floor_with_waiters
    @elevators.find { |e| e[:car].waiting? && !@floors[e[:car].current_floor].has_waiters? }
  end

  def elevator_waiting_with_riders
    @elevators.find { |e| e[:car].waiting? && e[:car].has_riders? }
  end

  def next_floor
    @floors.find { |f| f.call_down || f.call_up }
  end

 def next_elevator
   @elevators.find { |e| e[:car].status == 'waiting' }
 end



  # def logic_fcfs(request)
  #   elevator = @elevators[@@next_elevator]
  #   elevator
  # end

  def logic_sstf(request)
    elevator = nil
    request_floor = request[:floor]
    diffs = []
    # Measure distance to request floor from each elevator.
    @elevators.each do |e|
      if request_floor > e[:car].current_floor
        if e[:car].going_down?
          diffs << @num_floors + 1  # don't consider this elevator.
        else  # elevator is going up or is stationery.
          diffs << request_floor - e[:car].current_floor
        end
      elsif request_floor < e[:car].current_floor
        if e[:car].going_up?
          diffs << @num_floors + 1  # don't consider this elevator.
        else  # elevator is going down or is stationery.
          diffs << e[:car].current_floor - request_floor
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

  def select_elevator(request)
    elevator = nil
    case @logic
    when 'FCFS'    # First Come, First Served
      elevator = logic_fcfs(request)
    when 'SSTF'    # Shortest Seek Time First
      elevator = logic_sstf(request)
    when 'SCAN'    # Elevator Algorithm
    when 'L-SCAN'  # Look SCAN
    when 'C-SCAN'  # Circular SCAN
    when 'C-LOOK'  # Circular LOOK
    else
      raise "Invalid logic: #{@logic}"
    end
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, "Elevator #{elevator[:id]} selected")
    elevator
  end
end


# def next_destination(destinations)
#   destination = @elevator_status[:location]
#   destination += 1
#   if destination == @floors.length
#     destination = 1
#   end
#   return destination
#
#
#
#
#   msg "NEXT DESTINATION: #{destination}, DIRECTION: #{@elevator_status[:direction]}", Logger::DEBUG_3
#
#   if going_up?
#     # Return nearest stop above current location.
#     up_index = destinations.slice(current_floor...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
#
#     if !up_index.nil?
#       destination = up_index + current_floor
#
#       # If car is full, don't consider current floor as a destination (for pickups only).
#       if car_full? && destination == current_floor && !discharge_on?(current_floor)
#         up_index = destinations.slice(current_floor + 1...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
#         destination = up_index + current_floor + 1 if !up_index.nil?
#       end
#     end
#     @elevator_status[:direction] = 'down' if up_index.nil?
#   end
#
#   if going_down?
#     # Return nearest stop below current location.
#     down_index = destinations.slice(0..current_floor).rindex { |destination| !destination.nil? }
#
#     if !down_index.nil?
#       destination = down_index
#
#       # If car is full, don't consider current floor as a destination.
#       if car_full? && destination == current_floor
#         down_index = destinations.slice(0...current_floor).index { |destination| !destination.nil? }
#         destination = down_index if !down_index.nil?
#       end
#     end
#     @elevator_status[:direction] = '--' if down_index.nil?
#   end
#
#   if stationary? || @elevator_status[:direction].nil?
#     # Return nearest stop to current location and set appropriate @elevator_status[:direction].
#     up_index = @elevator_status[:destinations].slice(current_floor+1...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
#     down_index = @elevator_status[:destinations].slice(0..current_floor-1).rindex { |destination| !destination.nil? }
#     if up_index.nil? && down_index.nil?
#       destination = current_floor
#     elsif !up_index.nil? && !down_index.nil?
#       # If upper floor closer than lower floor, go up.
#       if up_index < down_index
#         @elevator_status[:direction] = 'up'
#         destination = up_index + current_floor + 1
#       else
#         @elevator_status[:direction] = 'down'
#         destination = down_index
#       end
#     elsif !up_index.nil?
#       @elevator_status[:direction] = 'up'
#       destination = up_index + current_floor + 1
#     else
#       @elevator_status[:direction] = 'down'
#       destination = down_index
#     end
#   end
#   destination
# end
#
# # Return the next planned direction of travel for this car.
# def next_direction
#   case next_stop <=> current_floor
#   when -1
#     'dn'
#   when 0
#     '--'
#   when 1
#     'up'
#   end
# end
#
#
# ### CONTROLLER SHOULD DETERMINE THE CAR'S NEXT STOP. NOT THE CAR. CAR JUST GOES TO WHERE ITS TOLD.
#
# ### HAVE CAR ASK CONTROLLER LOGIC
#    ### ELEVATOR -> QUEUE -> CONTROLLER: I'm available. Send next command.
#    ### CONTROLLER -> QUEUE -> ELEVATOR: [hold, goto x]
#
# # Given the existing list of planned stops, which one
# def next_stop
#
#
#   1. Of current riders, find closest stop to current location.
#   2. Else find closest stop to current_location.
#
#
#
#
#   if stationary? || @elevator_status[:direction].nil?
#     # Return nearest stop to current location and set appropriate @elevator_status[:direction].
#     up_index = @elevator_status[:destinations].slice(current_floor+1...@elevator_status[:destinations].length).index { |destination| !destination.nil? }
#     down_index = @elevator_status[:destinations].slice(0..current_floor-1).rindex { |destination| !destination.nil? }
#     if up_index.nil? && down_index.nil?
#       destination = current_floor
#     elsif !up_index.nil? && !down_index.nil?
#       # If upper floor closer than lower floor, go up.
#       if up_index < down_index
#         @elevator_status[:direction] = 'up'
#         destination = up_index + current_floor + 1
#       else
#         @elevator_status[:direction] = 'down'
#         destination = down_index
#       end
#     elsif !up_index.nil?
#       @elevator_status[:direction] = 'up'
#       destination = up_index + current_floor + 1
#     else
#       @elevator_status[:direction] = 'down'
#       destination = down_index
#     end
#   end
#
# end
#
