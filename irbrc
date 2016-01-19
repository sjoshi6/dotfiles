%w{rubygems irb/ext/save-history}.each do |lib| 
  begin 
    require lib 
  rescue LoadError => err
    $stderr.puts "Couldn't load #{lib}: #{err}"
  end
end


#Wirble.init and Wirble.colorize and maybe more afterwards
%w{init colorize}.each { |str| Wirble.send(str) }

IRB_START_TIME = Time.now

# Prompt behavior
ARGV.concat [ "--readline", "--prompt-mode", "simple" ]

#########################
ANSI_BOLD       = "\033[1m"
ANSI_RESET      = "\033[0m"
ANSI_LGRAY    = "\033[0;37m"
ANSI_GRAY     = "\033[1;30m"
ANSI_BLUE     = "\033[1;33m"
ANSI_RED     = "\033[1;32m"

class Object
  def pm(*options) # Print methods
    methods = self.methods
    methods -= Object.methods unless options.include? :more
    filter = options.select {|opt| opt.kind_of? Regexp}.first
    methods = methods.select {|name| name =~ filter} if filter

    data = methods.sort.collect do |name|
      method = self.method(name)
      if method.arity == 0
        args = "()"
      elsif method.arity > 0
        n = method.arity
        args = "(#{(1..n).collect {|i| "arg#{i}"}.join(", ")})"
      elsif method.arity < 0
        n = -method.arity
        args = "(#{(1..n).collect {|i| "arg#{i}"}.join(", ")}, ...)"
      end
      klass = $1 if method.inspect =~ /Method: (.*?)#/
      [name, args, klass]
    end
    max_name = data.collect {|item| item[0].size}.max
    max_args = data.collect {|item| item[1].size}.max
    data.each do |item| 
      print "#{ANSI_LGRAY}#{item[0].to_s.rjust(max_name)}#{ANSI_RESET}"
      print "#{ANSI_BLUE}#{item[1].to_s.ljust(max_args)}#{ANSI_RESET}"
      print "#{ANSI_RED}#{item[2]}#{ANSI_RESET}\n"
    end
    data.size
  end
end
#########################

#history
IRB.conf[:SAVE_HISTORY] = 100
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-save-history"

IRB.conf[:AUTO_INDENT] = true
IRB.conf[:PROMPT_MODE] = :SIMPLE

# Loaded when we fire up the Rails console
# among other things I put the current environment in the prompt

if ENV['RAILS_ENV']
  rails_env = ENV['RAILS_ENV']
  rails_root = File.basename(Dir.pwd)
  prompt = "#{rails_root}[#{rails_env.sub('production', 'prod').sub('development', 'dev')}]"
  IRB.conf[:PROMPT] ||= {}
  
  IRB.conf[:PROMPT][:RAILS] = {
    :PROMPT_I => "#{prompt}>> ",
    :PROMPT_S => "#{prompt}* ",
    :PROMPT_C => "#{prompt}? ",
    :RETURN   => "=> %s\n" 
  }
  
  IRB.conf[:PROMPT_MODE] = :RAILS
  
  #Redirect log to STDOUT, which means the console itself
  IRB.conf[:IRB_RC] = Proc.new do
    logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger = logger
    ActiveResource::Base.logger = logger
    ActiveRecord::Base.instance_eval { alias :[] :find }
  end
  
  ### RAILS SPECIFIC HELPER METHODS
  # TODO: DRY this out
  def log_ar_to (stream)
    ActiveRecord::Base.logger = expand_logger stream
    reload!
  end

  def log_ac_to (stream)
    logger = expand_logger stream
    ActionController::Base.logger = expand_logger stream
    reload!
  end
    
  def expand_log_file(name)
    "log/#{name.to_s}.log"
  end
  
  def expand_logger(name)
    if name.is_a? Symbol
      logger = expand_log_file name
    else
      logger = name
    end
    Logger.new logger
  end
end

### IRb HELPER METHODS

#clear the screen
def clear
  system('clear')
end
alias :cl :clear

#ruby documentation right on the console
# ie. ri Array#each
def ri(*names)
  system(%{ri #{names.map {|name| name.to_s}.join(" ")}})
end

### CORE EXTENSIONS
class Object
  #methods defined in the parent class of the object
  def local_methods
    (methods - Object.instance_methods).sort
  end
  
  #copy to pasteboard
  #pboard = general | ruler | find | font
  def to_pboard(pboard=:general)
    %x[printf %s "#{self.to_s}" | pbcopy -pboard #{pboard.to_s}]
    paste pboard
  end
  alias :to_pb :to_pboard

  #paste from given pasteboard
  #pboard = general | ruler | find | font
  def paste(pboard=:general)
    %x[pbpaste -pboard #{pboard.to_s}].chomp
  end
  
  def to_find
    self.to_pb :find
  end  

  def eigenclass
    class << self; self; end
  end

  def ql
    %x[qlmanage -p #{self.to_s} >& /dev/null  ]
  end
end

class Class
  public :include
  
  def class_methods
    (methods - Class.instance_methods - Object.methods).sort
  end
  
  #Returns an array of methods defined in the class, class methods and instance methods
  def defined_methods
    methods = {}
    
    methods[:instance] = new.local_methods
    methods[:class] = class_methods
    
    methods
  end
  
  def metaclass
    eigenclass
  end
end

### USEFUL ALIASES
alias q exit
