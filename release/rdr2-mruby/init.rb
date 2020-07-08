
load('./rdr2-mruby/constants.rb')

# uncomment to enable logs in console window, see dev_workspace for more
RDR2.create_console_window!

# initialise main script scheduler
RDR2.scripts_init!

# load .rb files from RDR2/scripts/rdr2-mruby/scripts/
$scripts_count = 0
RDR2.dir_glob("scripts","*.rb") do |path|
  begin
    OUT "[init.rb] loading #{path}"
    load(path)
    $scripts_count += 1
  rescue Exception => ex
    error_report!(ex,"init.rb")
  end
end

# invoked once this file finishes evaling
def RDR2.init!
  RDR2.scheduler.trigger!( :hook_start )
  
  # add error handler to display a notification onscreen ingame
  RDR2.scheduler.on( :script_error ) do |name,error|
    text = "#{name} raised #{error.class.to_s}, halting"
    RDR2.script{ notification_script(text,10,255,128,128,255) }
  end

  # basic metrics
  RDR2.scheduler.on( :tick_end ) do |time,start|
    $tick_sec ||= 0
    $tick_frame ||= 0
    $tick_times ||= RingBuffer.new( 120 )
    $tick_times << time - start
    $tick_frame += 1
    if Time.now.to_i != $tick_sec
      INFO "FPS: #{$tick_frame}, avg. time: #{'%.3f' % $tick_times.array.avg} ms"
      $tick_sec = Time.now.to_i
      $tick_frame = 0
    end
  end
end

# invoked each frame
def RDR2.tick!
  # tick scheduler each frame and force a GC at the end
  GC.disable
  begin
    RDR2.scheduler.tick!
  rescue => ex
    error_report!(ex,"RDR2.tick!")
  end
  GC.enable
  GC.start
  return nil
end

# invoked when the hook is unloaded (game exits or code reloads)
def RDR2.close!
  RDR2.scheduler.trigger!( :hook_end )
end



RDR2.script(:welcome) do
  text = "[github.com/lmc/rdr2-mruby] [runtime v#{RUNTIME_VERSION}, mruby v#{MRUBY_VERSION}] loaded #{$scripts_count} scripts"
  notification_script(text,5)
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


# RDR2.script(:test) do
#   # puts File.expand_path(".")
#   # f = File.new(File.expand_path("Loader.exe"),"r")
#   # f.close

#   flashed = {}
#   loop do

#     player = Native::GET_PLAYER_PED(0)
#     horse = Native::GET_MOUNT(player)
#     # Native::_SET_PED_SCALE(player,0.4)

#     size = 128
#     buffer = Native::Reference.new("#{[size].pack("L")}#{"\x00"*8*size}")
#     ret = Native::GET_PED_NEARBY_PEDS(player,buffer,0,0)
#     peds = buffer.to_s.unpack("Q*")[1..-1].reject{|i| i == 0}

#     peds.each do |ped|
#       coords_world = Native::GET_ENTITY_COORDS(ped,0,0)

#       r1, r2 = Native::Reference.new, Native::Reference.new
#       onscreen = Native::GET_SCREEN_COORD_FROM_WORLD_COORD(*coords_world,r1,r2)
#       screen_x, screen_y = r1.to_f, r2.to_f

#       # scale = Math.sin( Time.now.to_f ) + 2.0
#       # puts "#{scale}"
#       # Native::_SET_PED_SCALE(ped,scale)

#       # puts "#{ped} #{coords_world} #{onscreen} #{screen_x} #{screen_y}"
#       if onscreen && ped != horse
#         # Native::_FORCE_LIGHTNING_FLASH_AT_COORDS(*coords_world)

#         # if !flashed[ped]
#         #   flashed[ped] = true
#         #   Native::_FORCE_LIGHTNING_FLASH_AT_COORDS(*coords_world)
#         # end

#         model = Native::GET_ENTITY_MODEL(ped)
#         data = [
#           # Native::_0x3B005FF0538ED2A9(ped),
#           Native::GET_ANIMAL_TUNING_FLOAT_PARAM(ped,0),
#           Native::GET_ANIMAL_TUNING_FLOAT_PARAM(ped,1),
#           Native::GET_ANIMAL_TUNING_FLOAT_PARAM(ped,2),
#           Native::GET_ANIMAL_TUNING_FLOAT_PARAM(ped,3),
#           Native::GET_ANIMAL_TUNING_FLOAT_PARAM(ped,4),
#         ].map{|i| '%.3f' % i}
#         text = "#{model.to_s(16).upcase}\n#{data.join("\n")}"
#         # Native::DRAW_RECT(screen_x-0.025,screen_y-0.025,0.05,0.05,255,255,255,255,false,false)
#         # RDR2.draw_text(screen_x-0.05,screen_y-0.05,0.1,0.15,0,0,0,255,text)
#       end

#     end

#     wait(0)(  )
#   end
# end

# RDR2.script(:test) do

#   # # Native::CLEAR_OVERRIDE_WEATHER()
#   # Native::_SET_WEATHER_TYPE( Native::GET_HASH_KEY("SUNNY") , true , true , false , 0.0 , false)
#   # Native::PAUSE_CLOCK(true, 0)

#   str = " " * 1024 * 1024 * 16

#   loop do
#     puts "_UI_IS_SINGLEPLAYER_PAUSE_MENU_ACTIVE: #{Native::_UI_IS_SINGLEPLAYER_PAUSE_MENU_ACTIVE()}"
#     puts "IS_PAUSE_MENU_ACTIVE: #{Native::IS_PAUSE_MENU_ACTIVE()}"
#     wait(1000)
#   end
# end

# pad hashes
# -124244224 : left trigger
# -128997553 : left trigger
# -171675621 : triangle (on foot only)
# -349518703 : square
# -654888872 : dpad up
# -393875690 : l1
# -399233038 : dpad down (sometimes)
# 1141111167 : dpad down (sometimes)
# -432665970 : l1
# -562475458 : r1
# 1367437629 : x
# 1287709438 : dpad right (blocked sometimes?)
# 1940454787 : dpad up
# 1980406895 : dpad up
# 613911080 : dpad up
# 184129944 : dpad left
# 648122183 : circle
# 992265328 : circle
# 1644850270 : select
