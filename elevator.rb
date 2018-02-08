require_relative 'app/classes/controller'
require_relative 'app/classes/elevator_car'

controller_q = Queue.new

controller_t = Thread.new('controller') do |name|
  controller = Controller.new(controller_q).run
end

puts '  GOTO 6'
controller_q << {cmd: 'GOTO', floor: '6', pickup: [4, 2, 1]}   # pickup: array of passengers' destinations, 1 per passenger boarding
puts '  CALL 2 UP'
controller_q << {cmd: 'CALL', floor: '2', direction: 'up', pickup: [4]}   # pickup: array of passengers' destinations, 1 per passenger boarding
puts '  GOTO 4'
controller_q << {cmd: 'CALL', floor: '4', direction: 'up', pickup: []}   # pickup: array of passengers' destinations, 1 per passenger boarding
puts '  GOTO 1'
controller_q << {cmd: 'CALL', floor: '1', direction: 'up', pickup: []}   # pickup: array of passengers' destinations, 1 per passenger boarding

puts '  END'
controller_q << nil
controller_t.join()
controller_q.close
