
=begin
NEXT:
* DONE: use natives.json to generate functions
* DONE: port over ruby code
* DONE: include pack/io
* DONE: include keyboard hook code
* DONE: check getGlobalPtr code
* fix/suppress warnings in vendor code
* DONE: methods to set game/console window positions
* DONE: use mrb_raise for wrong number of args to native functions
* DONE: use pack/unpack for Reference handling, remove reference_to_foo funcs
* DONE: include Pointer class from laptop
* web server IDE - GET files, POST to save, use ace editor, reload button, screenshot
* DONE: option to bind only to localhost
* Struct
* Pack/Unpack module helpers
* memprof
* runtime metrics
* split up c/ruby code into more files
* lifecycle callbacks (load/unload/save/load/per-frame/per-script-tick/before/after)
* prevent use of world pool functions during load (they'll freeze the game)
* cacheable values like player ped id, etc. - reset each frame
* control hashes from scripthookdotnet
* c function to set failsafe reload key
* wrappers around detours library - look at redhook2
* provide values for reference vars - ie. DELETE_ENTITY
=end

puts "[boot.rb]"

RUNTIME_VERSION = "0.0.4"



LOGGER = nil # set later

def OUT(*args);    LOGGER.log(:notice,*args); end
def LOG(*args);    LOGGER.log(:info,  *args); end

def DEBUG(*args);  LOGGER.log(:debug, *args); end
def INFO(*args);   LOGGER.log(:info,  *args); end
def NOTICE(*args); LOGGER.log(:notice,*args); end
def WARN(*args);   LOGGER.log(:warn,  *args); end
def ERROR(*args);  LOGGER.log(:warn,  *args); end



def error_report!(ex, tag = nil)
  tag = tag ? "[#{tag}] " : ""
  OUT "#{tag}#{ex.class}: #{ex.message}"
  ex.backtrace.each{|bt| OUT "#{tag}#{bt}" }
end

def essential!(name = nil,&block)
  begin
    block.call
  rescue Exception => ex
    # if name
    #   ERROR "[#{name}] #{ex.class.to_s}: #{ex.message}"
    # else
    #   ERROR "!!! #{ex.class.to_s}: #{ex.message}"
    # end
    # ex.backtrace.each do |bt|
    #   DEBUG "  #{bt}"
    # end
    error_report!(ex,name)
    raise ex
  end
end

def load(path)
  code = RDR2.file_read(path)
  raise ArgumentError, "error loading #{path.inspect}" if !code
  eval(code,nil,path)
end



essential!("boot.rb") do

  class Array
    def sum
      self.inject(:+)
    end

    def avg
      (self.sum || 0.0) / self.size
    end

    def max
      acc = 0
      self.each do |i|
        acc = i if i > acc
      end
      acc
    end

    def to_hash
      Hash[ self ]
    end
  end



  class RingBuffer

    attr_accessor :max_size, :array

    def initialize(*args)
      case args.size
      when 2
        @max_size = args[0]
        @array = [ args[1] ] * @max_size
      when 1
        @max_size = args[0]
        @array = []
      else
        raise ArgumentError
      end
    end

    def <<(value)
      @array << value
      @array.shift if @array.size > @max_size
    end

    def to_a
      @array
    end

  end



  class Logger
    LEVELS = [:debug,:info,:notice,:warn,:error]
    LEVELS_INVERT = Hash[ LEVELS.each_with_index.map{|lvl,i| [lvl,i] } ]

    attr_accessor :level, :output, :buffer

    def initialize(level = :debug, output = $stdout, buffer = nil)
      @level = level
      @output = output
      @buffer = buffer
    end

    def log(loglvl,*args)
      str = args.map(&:to_s).join
      if LEVELS_INVERT[loglvl] >= LEVELS_INVERT[@level]
        @output.puts( str )
        # FIXME: should buffer always receive logs regardless of level ?
        @buffer << str if @buffer
      end
    end

    LEVELS.each do |loglvl|
      define_method(loglvl) do |*args|
        self.log(loglvl,*args)
      end
    end
  end

  LOGGER = Logger.new
  LOGGER.buffer = RingBuffer.new( 256 )

  def OUT(*args);    LOGGER.log(:notice,*args); end
  def LOG(*args);    LOGGER.log(:info,  *args); end

  def DEBUG(*args);  LOGGER.log(:debug, *args); end
  def INFO(*args);   LOGGER.log(:info,  *args); end
  def NOTICE(*args); LOGGER.log(:notice,*args); end
  def WARN(*args);   LOGGER.log(:warn,  *args); end
  def ERROR(*args);  LOGGER.log(:warn,  *args); end



  class Callbacks

    def initialize( proxy = nil )
      @handlers = {}

      if proxy
        def proxy.callbacks();            @callbacks;                        end
        def proxy.callbacks=(value);      @callbacks = value;                end
        def proxy.on(*args,&block);       @callbacks.on(*args,&block);       end
        def proxy.trigger!(*args,&block); @callbacks.trigger!(*args,&block); end
        proxy.callbacks = self
      end
    end

    def register( *events )
      # DEBUG "register: #{events}"
      events.each{|event| @handlers[event] = [] }
    end

    def on( event , &block )
      # DEBUG "on: #{event.inspect} #{@handlers[event].inspect}"
      raise ArgumentError, "no registered event #{event.inspect} (#{@handlers.keys.sort})" if !@handlers[event]
      @handlers[event] << block
    end

    def trigger!( event , *args )
      # DEBUG "trigger!: #{event.inspect} #{@handlers[event].inspect}"
      raise ArgumentError, "no registered event #{event.inspect} (#{@handlers.keys.sort})" if !@handlers[event]
      @handlers[event].each{|c| c.call(*args) }
    end

  end



  class Pointer
    attr_accessor :address

    def initialize(address)
      self.address = address
    end

    def read(bytes)
      RDR2.memory_read( self.address , bytes )
    end

    def write(value)
      RDR2.memory_write( self.address , value )
    end

    def integer
      RDR2.memory_read( self.address , 8 ).unpack("q")[0]
    end
    def integer=(value)
      RDR2.memory_write( self.address , [value].pack("q") )
    end

    def float
      RDR2.memory_read( self.address , 4 ).unpack("f")[0]
    end
    def float=(value)
      RDR2.memory_write( self.address , [value].pack("f") )
    end

    def string
      str = ""
      i = 0
      loop do
        chr = RDR2.memory_read( self.address + i , 1 )
        break if chr == "\x00" # read until zero byte
        str << chr
        i += 1
      end
      str
    end
    def string=(value)
      RDR2.memory_write( self.address , value )
    end

    # Vector3 struct is { float x; float pad0; float y; float pad1; float z; float pad2; }
    def vector3
      floats = RDR2.memory_read( self.address , 24 ).unpack("f*")
      Vector3.new( *floats.values_at(0,2,4) )
    end
    def vector3=(value)
      bytes = [value.x,0.0,value.y,0.0,value.z,0.0].pack("f")
      RDR2.memory_write( self.address , bytes )
    end

    def pointer
      self.class.new( self.integer )
    end

  end



  class Reference < Pointer
    attr_accessor :buffer

    def initialize(size = 32)
      @buffer = "\x00" * size
      super(self.address)
    end

    def address
      # returns address of @buffer's C string
      RDR2.reference_to_pointer(self)
    end

    def __buffer
      @buffer
    end
  end

  class IntegerReference < Reference
    def initialize; super(8); end
  end

  class FloatReference < Reference
    def initialize; super(4); end
  end

  class Vector3Reference < Reference
    def initialize; super(24); end
  end



  class Struct

    def self.define(name,&block)
      
    end

  end



  class Vector3 < Array
    def initialize(*args)
      if args.size == 0
        self.x = 0.0 
        self.y = 0.0 
        self.z = 0.0 
      elsif args.size == 3
        __load(*args)
      end
    end

    def __load(*args)
      replace(args)
    end

    def inspect
      "Vector3#{super}"
    end

    def x; self[0]; end
    def y; self[1]; end
    def z; self[2]; end
    def x=(v); self[0] = v; end
    def y=(v); self[1] = v; end
    def z=(v); self[2] = v; end

    def zero?
      self.sum == 0.0
    end

    def nonzero?
      self.sum != 0.0
    end
  end


  class YieldAccumulator
    attr_accessor :values

    def initialize
      clear!
    end

    def clear!
      @values = []
    end

    def to_proc
      ->(*args){ @values << args }
    end
  end



  module RDR2

    class Script
      attr_accessor :__script_name
      attr_accessor :__script_block
      attr_accessor :__script_fiber

      def initialize(name,&block)
        self.__script_name = name
        self.__script_block = block
        self.__script_fiber = Fiber.new do
          self.instance_eval(&block)
        end
      end

      def call
        self.__script_fiber.resume
      end

      def wait(ms)
        Fiber.yield(ms)
      end
    end

    class Scheduler

      attr_accessor :scripts
      attr_accessor :scripts_next_tick
      attr_accessor :scripts_keep

      def initialize
        @scripts = {}
        @scripts_next_tick = {}
        @scripts_keep = {}
        @scripts_start_time = Time.now.to_i

        @callbacks = Callbacks.new( self )
        @callbacks.register( :tick_start , :tick_end )
        @callbacks.register( :script_tick_start , :script_tick_end )
        @callbacks.register( :script_error )
        @callbacks.register( :script_register , :script_deregister )
        @callbacks.register( :script_schedule , :script_halt )

        # TODO: only for RDR2 module, not general scheduler ?
        @callbacks.register( :hook_start , :hook_end )
      end

      def register!( name = nil , script = nil , &block )
        name ||= self.new_script_name
        script ||= RDR2::Script.new(name,&block) if block_given?
        @scripts[name] = script
        @callbacks.trigger!( :script_register , name )
        return name
      end

      def schedule!( name , delay = 0 )
        @scripts_next_tick[ name ] = 0
        @callbacks.trigger!( :script_schedule , name )
      end

      def keep!( name )
        @scripts_keep[ name ] = true
      end

      def terminate!( name )
        self.halt!( name )
        self.deregister!( name ) if !@scripts_keep[ name ]
      end

      def halt!( name )
        @scripts_next_tick[ name ] = nil
        @callbacks.trigger!( :script_halt , name )
      end

      def deregister!( name )
        self.halt!( name )
        @scripts.delete( name )
        @callbacks.trigger!( :script_deregister , name )
      end

      def []( name )
        # ensure scripts have ticked at least once to allow methods
        # to be defined, etc. before other scripts can access them
        if @scripts_next_tick[name] != 0
          return @scripts[name]
        end
        nil
      end

      def tick!
        now = self.now
        @scripts.compact!
        @scripts_next_tick.compact!

        @callbacks.trigger!( :tick_start , now )

        @scripts_next_tick.each_pair do |name,next_tick|
          if now >= next_tick

            error = nil
            retval = begin
              @scripts[name].call
            rescue => ex
              error = ex
            end

            case retval
            when Fixnum
              @scripts_next_tick[name] = now + retval
            else
              if error
                text = "[scripts_tick! #{name}] raised #{error.class.to_s}, halting"
                WARN text
                error_report!(error,"Scheduler#tick! #{name}")
                @callbacks.trigger!( :script_error , name , error )
                self.terminate!( name )
              else
                # DEBUG "[scripts_tick! #{name}] returned #{retval.inspect}, halting"
                self.terminate!( name )
              end
            end
          end
        end

        @callbacks.trigger!( :tick_end , self.now, now )

      end

      def now
        t = Time.now
        ((t.to_i - @scripts_start_time) * 1000) + (t.usec / 1000)
      end

      def new_script_name
        @script_name_counter ||= 0
        :"noname#{@script_name_counter += 1}"
      end

    end



    def self.boot!
      OUT "[RDR2.boot!]"
    end

    def self.init!
      OUT "[RDR2.init!]"
    end

    def self.tick!
      OUT "[RDR2.tick!] default RDR2.tick!, override me"
    end

    def self.close!
      OUT "[RDR2.close!]"      
    end

    def self.wait( ms )
      Fiber.yield(ms)
    end

    def self.scheduler
      @scheduler
    end

    def self.scripts_init!
      @scheduler = Scheduler.new
    end

    def self.script( name = nil , script = nil , &block )
      name = @scheduler.register!(name,script,&block)
      @scheduler.schedule!(name)
    end

    def self.library( name , script = nil , &block)
      name = @scheduler.register!(name,script,&block)
      @scheduler.keep!(name)
      @scheduler.schedule!(name)
    end

    def self.[](name)
      @scheduler[name]
    end

  end


  # load vendor .rb files 
  RDR2.dir_glob("vendor\\mruby-io","*.rb") do |path|
    begin
      load(path)
    rescue => ex
      error_report!(ex)
    end
  end


end



OUT "[boot.rb] end"
