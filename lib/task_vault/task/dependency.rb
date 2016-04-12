

class TaskVault
  
  class Dependency
    attr_reader :type, :task, :value_selector
    
    TYPES = [
      :wait, # Waits until the dependencies have run at least once since this task last ran.
      :prereq, # Prereq waits, but only executes if the dependencies succeed.
      :after # Waits for dependencies to finish entirely. If they repeat this wont run until the stop repeating.
    ]
    
    def initialize type, *task
      @selectors = Hash.new
      self.type = type
      self.task = task
    end
    
    def type= t
      raise ArgumentError, "Invalid dependency type '#{t}'. Options are #{TYPES}" unless TYPES.include?(t)
      @type = t
    end
    
    def task= *tasks
      @tasks = tasks
    end
    
    # Selectors determine what values should be grabbed from the output of
    # dependencies. The first argument is an array of strings or regular expressions
    # that the selected output should match. It can also be a slice or array of 
    # integers to grab from the array of output from the dependency. Match is used
    # to selectively grab a piece of any values that meet the criteria. Matches
    # must be Regexps. The arg is the name of the argument that should be associated
    # with the call to this task. For example it could be a cmdline flag like '-f'.
    def add_selector criteria, match = /.*/, flag = nil
      @selectors[criteria] = {match: match, flag: flag}
    end
    
  end
  
end