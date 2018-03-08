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
# logic:       Controller logic to use: FCFS, SCAN, SSTF, L-SCAN, C-SCAN, C-LOOK.
# modifiers:   <none yet>
# floors:      Number of floors.
# elevators:   Number of elevators.
# occupants:   Number of building occupants.
# debug_level: Console logger debug level: DEBUG, INFO, WARN, etc.

sim_runs = []
# sim_runs << {name: 'testing 1', logic:'FCFS', modifiers: {}, floors: 10, elevators:  1, occupants:   1, debug_level: Logger::DEBUG}
# sim_runs << {name: 'testing 2', logic:'FCFS', modifiers: {}, floors: 10, elevators:  1, occupants:   2, debug_level: Logger::DEBUG}
sim_runs << {name: 'simple 1',  logic:'SCAN', modifiers: {}, floors: 4, elevators:  1, occupants:   40, debug_level: Logger::DEBUG}
# sim_runs << {name: 'simple 2',  logic:'FCFS', modifiers: {}, floors: 10, elevators:  2, occupants:   40, debug_level: Logger::DEBUG}
# sim_runs << {name: 'smarts 1',  logic:'SSTF', modifiers: {}, floors: 10, elevators:  1, occupants:   40, debug_level: Logger::DEBUG}
# sim_runs << {name: 'smarts 2',  logic:'SSTF', modifiers: {}, floors: 10, elevators:  2, occupants:   40, debug_level: Logger::DEBUG}

sim_runs.each_with_index do |run, index|
  puts "> > > Begin Run #{index}: #{run}"
  Simulator.new(run[:name], run[:logic], run[:modifiers], run[:floors], run[:elevators], run[:occupants], run[:debug_level]).run
  puts ">  > > End Run #{index}: #{run}"
end
