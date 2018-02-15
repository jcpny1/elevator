# A Console Logger.
module Logger

  # Modules:
  #   'Controller'
  #   'Elevator'
  #   'Simulator'
  #   '*'

  DEBUG_3 = 0  # extreme detail degbugging messages
  DEBUG_2 = 1  # medium detail degbugging messages
  DEBUG_1 = 2  # least detail degbugging messages
  INFO    = 3  # informational message
  WARN    = 4  # waring message
  ERROR   = 5  # error message
  NONE    = 6  # no log messages

  # modules - specify a hash list of modules to report on, or '*' for all modules.
  # level - specify the level of messages to report. The level requested and all less critical levels will be reported.
  def self.init(modules, level)
    @modules = modules
    @level = level
    @all_modules = false
    @all_modules = true if @modules.include?('*')
  end

  def self.msg(time, module_name, debug_level, msg_text)
    if (debug_level >= @level) && (@all_modules || @module.include?(module_name))
      puts "Time: %6.2f: #{module_name}: #{msg_text}" % time
    end
  end
end
