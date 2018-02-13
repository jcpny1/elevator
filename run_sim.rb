require 'pry'
require_relative 'app/classes/controller'
require_relative 'app/classes/elevator'
require_relative 'app/classes/floor'
require_relative 'app/classes/occupant'
require_relative 'app/classes/simulation'

# logic:
#   FCFS   (First Come, First Serve): Requests are processed in the order received.
#   SSTF   (Shortest Seek Time First): Shortest travel distance in any direction from current location.
#   SCAN   (Elevator Algorithm): Move in one direction. At end of movement, reverse direction.
#   L-SCAN (Look SCAN): Like SCAN, but reverse direction when last request in current direction is serviced.
#   C-SCAN (Circular SCAN): Like SCAN, but ine direction only. At end of movement, return to beginning and SCAN again.
#   C-LOOK (Circular LOOK): Like C-SCAN, but do not travel to end of movement. Return to beginning when last request is serviced.

# modifiers {}:
#   nopick: Do not pickup passengers traveling in opposite direction.

# floors: Number of floors.

# elevators: Number of elevators.

# occupants: Number of building occupants.

# debug true|false: Execute debug logic, messages, etc., if any.

# puts "Run 1: logic:'FCFS', modifiers: {}, floors: 10, elevators: 1, occupants: 40, debug:false"
# Simulation.new(logic:'FCFS', modifiers: {}, floors: 10, elevators: 1, occupants: 40, debug:false).run
# puts
# puts "Run 2: logic:'FCFS', modifiers: {}, floors: 10, elevators: 2, occupants: 40, debug:false"
# Simulation.new(logic:'FCFS', modifiers: {}, floors: 10, elevators: 2, occupants: 40, debug:false).run
# puts
puts "Run 3: logic:'SSTF', modifiers: {'NOPICK': true}, floors: 10, elevators: 2, occupants: 100, debug:true"
Simulation.new(logic:'SSTF', modifiers: {'NOPICK': false}, floors: 10, elevators: 2, occupants: 100, debug:false).run
