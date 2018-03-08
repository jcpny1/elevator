# ELEVATOR

## Overview

The Elevator App is an elevator design tool used to test various scheduling algorithms in an effort to minimize passenger wait time, passenger trip time, and elevator expenses.

The app consists of three main components, each of which operates in their own thread:
* the Simulator,
* the Controller,
* the Elevators.

The Controller will command elevator movements in response to floor call buttons in each floor's elevator lobby and in-elevator floor button activations.
The Controller will command the elevators to move according to the logic that is requested for the simulation.
In order to test the efficiency of various scenarios, multiple logic algorithms have been coded.

The most recent simulation results can be found in Results.xlsx.

Currently implemented logic models are:
* FCFS  (First Come, First Served) Elevators service requests in the order received without regard to distance or direction.
* SCAN  (Scan) Elevators travel from first floor to last floor, then travel from last floor to first floor, then repeat.
* SSTF  (Shortest Seek Time First) Elevators service closest request to current position in any direction.

Upcoming logic:
* L-SCAN (Look SCAN): Like SCAN, but instead of traveling to last or first floor, reverse direction when last request in current direction is serviced.
* C-SCAN (Circular SCAN): Like SCAN, but travel from first to last floor only. At last floor, return directly to first floor and SCAN again.
* C-LOOK (Circular LOOK): Like L-SCAN with C-SCAN (return directly to first floor when last request in current direction is serviced).

Regardless of logic selected:
* passengers on board an elevator will always have priority over passengers waiting for an elevator to arrive.
E.G., once an elevator is carrying passengers up, it will not travel down to pickup or discharge another passenger.
* passengers waiting for an up elevator will not board an elevator traveling down, and vice versa.

[NOTE: The project repository is set up as a Rail API app (for future enhancements), but presently is just command line Ruby.]

### Sample Output
```
~/projects/elevator(master)$ ./run_sim
> > > Begin Run 0: {:name=>"simple 1", :logic=>"FCFS", :modifiers=>{}, :floors=>4, :elevators=>1, :occupants=>10, :debug_level=>"INFO"}
T +    0.00: Simulator 0: starting
T +    0.00: Simulator 0: Morning Rush Begin
T +   49.00: Floor 1: call up
T +   49.00: Elevator 0: picked up 1 on 1
T +   49.00: Elevator 0: discharged 1 on 2
T +   59.00: Floor 1: call up
T +   60.00: Elevator 0: picked up 1 on 1
T +   60.00: Elevator 0: discharged 1 on 3
T +   76.00: Floor 1: call up
T +   77.00: Elevator 0: picked up 1 on 1
T +   84.00: Elevator 0: discharged 1 on 4
 .
 .
 .
T +  577.00: Simulator 0: Morning Rush End
T +  577.00: Simulator 0:   Name         : simple 1
T +  577.00: Simulator 0:   Logic        : FCFS
T +  577.00: Simulator 0:   Run Time     : 577.0
T +  577.00: Simulator 0:   Total Trips  :  10.0
T +  577.00: Simulator 0:   Avg Wait Time:   0.9
T +  577.00: Simulator 0:   Avg Trip Time:   4.4
T +  577.00: Simulator 0:   Max Wait Time:   1.0
T +  577.00: Simulator 0:   Max Trip Time:  20.0
T +  577.00: Simulator 0:   Elevator dx  : 420.0
T +  577.00: Simulator 0:     Elevator 0 : 420.0
T +  577.00: Simulator 0: Evening Rush Begin
T +  665.00: Floor 2: call down
T +  665.00: Elevator 0: picked up 1 on 2
T +  665.00: Elevator 0: discharged 1 on 1
T +  837.00: Floor 2: call down
T +  838.00: Elevator 0: picked up 1 on 2
T +  838.00: Elevator 0: discharged 1 on 1
T +  843.00: Floor 4: call down
T +  844.00: Elevator 0: picked up 1 on 4
T +  844.00: Elevator 0: discharged 1 on 1
 .
 .
 .
T + 1076.00: Simulator 0: Evening Rush End
T + 1076.00: Simulator 0:   Name         : simple 1
T + 1076.00: Simulator 0:   Logic        : FCFS
T + 1076.00: Simulator 0:   Run Time     : 1076.0
T + 1076.00: Simulator 0:   Total Trips  :  10.0
T + 1076.00: Simulator 0:   Avg Wait Time:   1.4
T + 1076.00: Simulator 0:   Avg Trip Time:   1.4
T + 1076.00: Simulator 0:   Max Wait Time:   2.0
T + 1076.00: Simulator 0:   Max Trip Time:   2.0
T + 1076.00: Simulator 0:   Elevator dx  : 420.0
T + 1076.00: Simulator 0:     Elevator 0 : 420.0
>  > > End Run 0: {:name=>"simple 1", :logic=>"FCFS", :modifiers=>{}, :floors=>4, :elevators=>1, :occupants=>10, :debug_level=>"INFO"}

real	1m48.261s
user	0m1.759s
sys	0m0.422s
~/projects/elevator(master)$
```

## History
```
20-Feb-18  1.0.0  Initial release. First Come, First Served logic complete. Morning and Evening Scenarios complete.  
```

## Installation

Elevator was developed using Ruby 2.4.2

```
$ ruby -v
ruby 2.4.2p198 (2017-09-14 revision 59899) [x86_64-linux]
```

### Initialize the project
* Clone the [Elevator Repository](https://github.com/jcpny1/elevator).
* `cd` into the project directory.
* `bundle install`

## Usage
* A default simulation configuration is provided in file `run_sim.rb`.
* To change the simulation configuration, edit file `run_sim.rb`.
* To run a simulation, enter `./run_sim`.

## Deployment

TBD

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jcpny1/elevator.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The application is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
