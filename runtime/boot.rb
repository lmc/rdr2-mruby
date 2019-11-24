
puts "[boot.rb]"

RUNTIME_VERSION = "0.0.1"

def OUT(*args)
  puts args.map(&:to_s).join(", ")
end

def essential!(name = nil,&block)
  begin
    block.call
  rescue => ex
    if name
      OUT "[#{name}] #{ex.class.to_s} #{ex.message}"
    else
      OUT "!!! #{ex.class.to_s} #{ex.message}"
    end
    ex.backtrace.each do |bt|
      OUT "  #{bt}"
    end
    raise ex
  end
end

def load(path)
  code = RDR2.file_read(path)
  raise ArgumentError, "error loading #{path.inspect}" if !code
  eval(code,nil,path)
end

def error_report!(ex, tag = nil)
  tag = tag ? "[#{tag}] " : ""
  OUT "#{tag}#{ex.class} #{ex.message}"
  ex.backtrace.each{|bt| OUT "#{tag}#{bt}" }
end

def notification_script(text, timeout = 5.0 ,r = 255, g = 255, b = 255, a = 255)
  # wait until initial loading screen completes
  wait(0) while Native::IS_SCREEN_FADED_IN() == 0
  # show welcome message for a while then exit
  started_at = Time.now
  until Time.now - timeout > started_at
    Native::DRAW_RECT(0.5, 0.02, 1.0, 0.04, 0, 0, 0, 192, false, false)
    RDR2.draw_text(0.005,0.0075,0.342,0.342,r,g,b,a,text)
    wait(0)
  end
end

def RDR2.draw_text(x,y,xs,ys,r,g,b,a,text)
  Native::SET_TEXT_SCALE(xs,ys)
  Native::_SET_TEXT_COLOR(r,g,b,a)
  native_str = Native::_CREATE_VAR_STRING(10,"LITERAL_STRING","#{text}")
  Native::_DISPLAY_TEXT(native_str,x,y)
end

class Reference
  def initialize(value = "\xFF" * 32)
    @buffer = value
  end

  def __buffer
    @buffer
  end

  def to_i
    RDR2.reference_to_i(self)
  end

  def to_f
    RDR2.reference_to_f(self)
  end

  def to_vector3
    RDR2.reference_to_vector3(self)
  end
end

essential!("boot.rb") do


  class Vector3 < Array
    def __load(*args)
      replace(args)
    end

    def inspect
      "Vector3#{super}"
    end

    def x; self[0]; end
    def y; self[1]; end
    def z; self[2]; end
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

    def self.boot!
      OUT "[RDR2.boot!]"
    end

    def self.init!
      OUT "[RDR2.init!]"
    end

    def self.tick!
      OUT "[RDR2.tick!] default RDR2.tick!, override me"
    end

    def self.scripts_init!
      @@scripts = {}
      @@scripts_next_tick = {}
      @@script_name_counter = 0
    end

    def self.script(name = nil,&block)
      name ||= self.script_name_new
      script = RDR2::Script.new(name,&block)
      @@scripts[name] = script
      @@scripts_next_tick[name] = 0
      return name
    end

    def self.scripts_tick!
      @@scripts_next_tick.each_pair do |name,next_tick|
        now = self.script_now
        if now >= next_tick

          error = nil
          retval = begin
            @@scripts[name].call
          rescue => ex
            error = ex
          end

          case retval
          when Fixnum
            @@scripts_next_tick[name] = now + retval
          else
            if error
              text = "[scripts_tick! #{name}] raised #{error.to_s}, halting"
              OUT text
              error_report!(error,"scripts_tick! #{name}")
              @@scripts_next_tick[name] = nil
              RDR2.script{ notification_script(text,10,255,128,128,255) }
            else
              # OUT "[scripts_tick! #{name}] returned #{retval.inspect}, halting"
              @@scripts_next_tick[name] = nil
            end
          end
        end
      end
      @@scripts_next_tick.compact!
    end

    def self.script_now
      t = Time.now
      (t.to_i * 1000) + (t.usec / 1000)
    end

    def self.script_name_new
      :"noname#{@@script_name_counter += 1}"
    end

  end

end

OUT "[boot.rb] end"
