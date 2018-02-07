# A Controller receives requests for elevator services and assigns elevators to service those requests.
class Controller

  @@simulation_time = 0  # seconds

  def initialize(request_q)
    @request_q = request_q
    @elevator_q = Queue.new
    @elevator_t = Thread.new('elevator') do |name|
      @elevator = ElevatorCar.new(@elevator_q).run
    end
  end

  def self.time
    @@simulation_time
  end

  def run
    while 1
      if @request_q.length > 0
        e = @request_q.deq # wait for nil to break loop
        @elevator_q << e
        # break if e.nil?
      end
      sleep 0.25
      @@simulation_time += 1
    end
    puts "Controller done. Simulation time: #{@@simulation_time}"
    @elevator_q << nil
    @elevator_t.join()
    @elevator_q.close
  end
end
