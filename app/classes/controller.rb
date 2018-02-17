# The Controller receives service requests from users and send commands to elevators.
# Requests for elevator services are received from floor call buttons. The Controller assigns an  elevator to service those requests.
# A Controller may also implement performance improvement functions such as commanding to stage at a particular floor in anticipation of a request.
class Controller
  LOGGER_MODULE = 'Controller'
  LOOP_DELAY    = 1.01  # in seconds.

  @@next_elevator = nil

  def initialize(request_q, elevators, num_floors, logic)
    @id = 0
    @request_q  = request_q
    @elevators  = elevators
    @num_floors = num_floors
    @logic = logic
    @@next_elevator = 0
    Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, 'created')
  end

  def run
    keep_running = true
    while keep_running
      while !@request_q.empty?
        request = @request_q.deq
        Logger::msg(Simulator::time, LOGGER_MODULE, @id, Logger::DEBUG, request.to_s)
        elevator = select_elevator(request)
        elevator[:car].controller_q << request
        # if request[:cmd] == 'END'
        #   @elevators.each { |elevator| elevator[:queue] << request }
        #   keep_running = false
        # else
        # end
      end
      sleep LOOP_DELAY
    end
  end

private

  def logic_fcfs(request)
    elevator = @elevators[@@next_elevator]
    @@next_elevator += 1
    @@next_elevator = 0 if @@next_elevator == @elevators.length
    elevator
  end

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
    when 'FCFS'    # First Come, First Serve
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
