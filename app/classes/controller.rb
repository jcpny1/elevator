# A Controller receives requests for elevator services and assigns elevators to service those requests.
class Controller

  END_OF_SIMULATION = 'END SIMULATION'
  NUM_ELEVATORS = 1

  @@simulation_time = 0.0  # seconds

  def initialize(request_q)
    @request_q = request_q
    @elevators = []

    NUM_ELEVATORS.times do |i|
      e_queue  = Queue.new
      e_thread = Thread.new("#{i}") { |id| ElevatorCar.new(id, e_queue).run }
      @elevators << { queue: e_queue, thread: e_thread }
    end
  end

  def run
    # Accept a simulator command. Pick an elevator. Pass command to elevator.
    while 1
      if @request_q.length > 0
        request = @request_q.deq
        if request[:cmd] === END_OF_SIMULATION
          @elevators.each { |elevator| elevator[:queue] << request }
          break
        else
          elevator = select_elevator(request)
          elevator[:queue] << request
        end
      end
      sleep 0.125
      @@simulation_time += 1.0
    end

    # Wait for elevators to complete their commands.
    while @elevators.reduce(false) { |status, elevator| status || elevator[:thread].status }
      sleep 0.125
      @@simulation_time += 1.0
    end

    # Elevators are done. Clean up.
    puts "Controller done. Simulated time: #{@@simulation_time}"
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
