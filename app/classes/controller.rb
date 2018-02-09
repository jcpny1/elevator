# A Controller receives requests for elevator services from floor call buttons then assigns elevators to service those requests.
# A Controller may also command an elevator to go to a particluar floor without receiving a call button request.
class Controller
  def initialize(request_q, elevators)
    @request_q = request_q
    @elevators = elevators
  end

  def run
    while 1
      if @request_q.length > 0
        request = @request_q.deq
        if request[:cmd] === 'END'
          @elevators.each { |elevator| elevator[:queue] << request }
          break
        else
          elevator = select_elevator(request)
          elevator[:queue] << request
        end
      end
      sleep 0.125
    end
  end

private

  def select_elevator(e)
    @elevators[0]
  end
end
