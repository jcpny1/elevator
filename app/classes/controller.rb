# A Controller receives requests for elevator services from floor call buttons then assigns elevators to service those requests.
# A Controller may also command an elevator to go to a particluar floor without receiving a call button request.
class Controller
  def initialize(request_q, elevators)
    @@next_elevator = 0
    @request_q = request_q
    @elevators = elevators
  end

  def run
    keep_running = true
    while keep_running
      while !@request_q.empty?
        request = @request_q.deq
        if request[:cmd] === 'END'
          @elevators.each { |elevator| elevator[:queue] << request }
          keep_running = false
        else
          elevator = select_elevator(request)
          elevator[:queue] << request
        end
      end
      sleep 0.25
    end
  end

private

  def select_elevator(e)
    elevator = @elevators[@@next_elevator]
    @@next_elevator += 1
    @@next_elevator = 0 if @@next_elevator === @elevators.length
    elevator
  end
end
