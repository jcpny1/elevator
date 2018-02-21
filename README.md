# ELEVATOR

## Overview

The Elevator App is an elevator design tool used to test various scheduling algorithms in an effort to minimize passenger wait time, passenger trip time, and elevator expenses.



It was created to meet the requirements of the [Flatiron School](https://flatironschool.com/)'s React Redux portfolio project.
The project repository is set up as a Rail API app (for future enhancements), but presently is just command line Ruby.

The app consists of three main components, each of which operates in their own thread:
* the Simulator,
* the Controller,
* the Elevators.

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
* To configure a simulation, edit the `run_sim.rb` file.
* To run a simulation, enter `./run_sim`.

## Deployment

TBD

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jcpny1/elevator.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The application is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
