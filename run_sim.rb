require 'pry'
require_relative 'app/classes/controller'
require_relative 'app/classes/elevator'
require_relative 'app/classes/floor'
require_relative 'app/classes/logger'
require_relative 'app/classes/occupant'
require_relative 'app/classes/simulator'

#
# Use this file to configure and start simulation runs.
#
# logic:
#   FCFS   (First Come, First Serve): Requests are processed in the order received.
#   SSTF   (Shortest Seek Time First): Shortest travel distance in any direction from current location.
#   SCAN   (Elevator Algorithm): Move in one direction. At end of movement, reverse direction.
#   L-SCAN (Look SCAN): Like SCAN, but reverse direction when last request in current direction is serviced.
#   C-SCAN (Circular SCAN): Like SCAN, but ine direction only. At end of movement, return to beginning and SCAN again.
#   C-LOOK (Circular LOOK): Like C-SCAN, but do not travel to end of movement. Return to beginning when last request is serviced.
# modifiers {}:
# floors: Number of floors.
# elevators: Number of elevators.
# occupants: Number of building occupants.
# debug_level: Console logger debug level: DEBUG, WARN, etc.

sim_runs = []
# sim_runs << {name: 'testing 1', logic:'FCFS', modifiers: {}, floors: 10, elevators:  1, occupants:   1, debug_level: Logger::DEBUG}
# sim_runs << {name: 'testing 2', logic:'FCFS', modifiers: {}, floors: 10, elevators:  1, occupants:   2, debug_level: Logger::DEBUG}
sim_runs << {name: 'simple 1',  logic:'SSTF', modifiers: {}, floors: 4, elevators:  1, occupants:   40, debug_level: Logger::INFO}
# sim_runs << {name: 'simple 2',  logic:'FCFS', modifiers: {}, floors: 10, elevators:  2, occupants:   40, debug_level: Logger::DEBUG}
# sim_runs << {name: 'smarts 1',  logic:'SSTF', modifiers: {}, floors: 10, elevators:  1, occupants:   40, debug_level: Logger::DEBUG}
# sim_runs << {name: 'smarts 2',  logic:'SSTF', modifiers: {}, floors: 10, elevators:  2, occupants:   40, debug_level: Logger::DEBUG}

sim_runs.each_with_index do |r, i|
  puts "> > > Begin Run #{i}: #{r}"
  Simulator.new(r[:name], r[:logic], r[:modifiers], r[:floors], r[:elevators], r[:occupants], r[:debug_level]).run
  puts ">  > > End Run #{i}: #{r}"
end
