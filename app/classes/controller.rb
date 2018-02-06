# A Controller receives requests for elevator services and assigns elevators to service those requests.
class Controller
  def initialize(request_q)
    @request_q = request_q
    @elevator_q = Queue.new
    @elevator_t = Thread.new('elevator') do |name|
      @elevator = ElevatorCar.new(@elevator_q).run
    end
  end

  def run
    while e = @request_q.deq # wait for nil to break loop
      @elevator_q << e
    end
    puts 'Controller done'
    @elevator_q << nil
    @elevator_t.join()
    @elevator_q.close
  end
end
