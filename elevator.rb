require_relative 'app/classes/controller'
require_relative 'app/classes/elevator_car'

command_q = Queue.new

controller_t = Thread.new('controller') do |name|
  controller = Controller.new(command_q).run
end

sleep 1
puts '  GOTO 6'
command_q << {cmd: 'GOTO', floor: '6'}
sleep 5
puts '  GOTO 4'
command_q << {cmd: 'GOTO', floor: '4'}
sleep 5
puts '  CALL 2 UP'
command_q << {cmd: 'CALL', floor: '2', direction: 'up'}
sleep 5
puts '  END'
command_q << nil

controller_t.join()
command_q.close
