require_relative 'app/classes/elevator_car'


q = Queue.new
threads = []

threads << Thread.new('elevator') { |name|
  elevator = ElevatorCar.new
  while e = q.deq # wait for nil to break loop
    dest = e[:floor].to_i
    puts '<' + e[:cmd] + ' ' + e[:floor] + '>'
    case e[:cmd]
    when 'GOTO'
      elevator.goto(e[:floor].to_i)
    end
  end
  puts name + ' thread done'
}

threads << Thread.new('command') { |name|
  puts 'GOTO 6'
  q << {cmd: 'GOTO', floor: '6'}
  sleep 15
  puts 'GOTO 4'
  q << {cmd: 'GOTO', floor: '4'}
  puts 'CALL 2 UP'
  q << {cmd: 'CALL', floor: '2', direction: 'up'}
  q << nil
}

threads.each { |thr| thr.join }
q.close

# case ARGV[0]
# when 'fib'
#   puts rt.fib(ARGV[1].to_i)
# else
#   puts 'Invalid option'
# end
