# A Controller receives requests for elevator services and assigns elevators to service those requests.
class Controller

  NUM_ELEVATORS = 1

  @@simulation_time = 0.0  # seconds

  def initialize(request_q)
    @request_q = request_q
    @elevators = []

    NUM_ELEVATORS.times do |i|
      e_queue  = Queue.new
      e_thread = Thread.new("Elevator #{i}") { |name| ElevatorCar.new(name, e_queue).run }
      @elevators << { queue: e_queue, thread: e_thread }
    end
  end

  def run
    while 1
      if @request_q.length > 0
        e = @request_q.deq
        elevator = select_elevator(e)
        elevator[:queue] << e
      end
# TODO we will be interpretting the command in a future release. So we'll be commanding elevator to terminate.
#      for now, we'll just check the status of the first elevator to see if it was commanded to terminate.
      break if !@elevators[0][:thread].status
      sleep 0.25
      @@simulation_time += 1.0
    end

    puts "Controller done. Simulation time: #{@@simulation_time}"
    @elevators.each do |elevator|
      elevator[:thread].join()
      elevator[:queue].close
    end
  end

  def self.time
    @@simulation_time
  end

private

  def select_elevator(e)
    @elevators[0]
  end
end
