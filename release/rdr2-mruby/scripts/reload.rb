
# also hardcoded to react to F12 in c code, that key can be used 
# as failsafe in case the mruby vm crashes globally to restart it
RDR2.script(:reload) do
  loop do
    if RDR2.key_just_up(0x7A,false) # F11
      RDR2.reload_next_tick!
    end
    wait(0)
  end
end

# RDR2.script(:aaaa) do

#   def update_cam(camera,pos,target)
#     Native::HIDE_HUD_AND_RADAR_THIS_FRAME()

#     Native::SET_CAM_FOV(camera,100.0)
#     Native::SET_CAM_COORD(camera,*pos)
#     Native::POINT_CAM_AT_COORD(camera,*target)
#     Native::SET_CAM_ACTIVE(camera, true)
#     Native::RENDER_SCRIPT_CAMS(true,false,0,true,true,0)

#     player_coords = pos
#     text = [
#       "x: #{'%.3f' % player_coords.x}", 
#       "y: #{'%.3f' % player_coords.y}",
#       "z: #{'%.3f' % player_coords.z}",
#     ].join(" , ")
#     RDR2.draw_text(0.755,0.0075,0.342,0.342,255,255,255,255,text)
#     RDR2.draw_text(0.7,0.8975,0.342*2,0.342*2,255,255,255,255,"twitter.com/lmcildoon\ngithub.com/lmc/rdr2-mruby")
#   end

#   def rotate(cam)
#     ct = Vector3.new( 2000.0 , -7000.0 , -8200.0 )
#     ct = Vector3.new( 3000.0 , -8000.0 , -3200.0 )
#     dist = 5600.0
#     height = 2000.0
#     phase = 0.0
#     loop do
#       phase += 0.01
#       cc = Vector3.new( Math.sin(phase) * dist , Math.cos(phase) * dist , height )
#       cc.x += ct.x
#       cc.y += ct.y
#       update_cam(cam,cc,ct)
#       wait(0)
#     end
#   end

#   def line(cam)
#     cc = Vector3.new( -6000.0 , -16000.0 , 600.0 )
#     ct = Vector3.new( -4000.0 , -15000.0 , 100.0 )
#     ct = Vector3.new( 7000.0 , -6700.0 , -100.0 )
#     state = 0
#     sp = 15.0
#     loop do
#       if state == 0
#         if cc.y > -1000.0
#           state = 1
#         end
#         cc.y += sp
#       elsif state == 1
#         if cc.y < -5000.0
#           state = 2
#         end
#         cc.x += sp
#         cc.y -= sp
#       else
#         cc.x += sp / 2
#         cc.y -= sp
#         cc.z += sp / 2
#       end
#       update_cam(cam,cc,ct)
#       wait(0)
#     end
#   end

#   Native::_SET_WEATHER_TYPE( Native::GET_HASH_KEY("HIGHPRESSURE") , true , true , false , 0.0 , false)
#   Native::PAUSE_CLOCK(true, 0)
#   Native::SET_CLOCK_TIME(17, 0, 0)
#   swap_char_model(nil)

#   # cc = Vector3.new( -6000.0 , -16000.0 , 600.0 )
#   # ct = Vector3.new( -4000.0 , -15000.0 , 100.0 )

#   # # cc = Vector3.new( -6000.0 , -16000.0 , 600.0 )
#   # ct = Vector3.new( 0.0 , -8000.0 , -4200.0 )
#   # dist = 4200.0
#   # height = 2200.0
#   # phase = 0.0

#   Native::SET_PLAYER_CONTROL(Native::PLAYER_ID(), 1,1,1)
#   camera = Native::CREATE_CAMERA_WITH_PARAMS( 26379945 , 0.0,0.0,100.0, -3.0,0.0,30.0, false, 2 )
#   # Native::SET_CAM_PARAMS(cam, *cc, -5.0,0.0,30.0, 90.0, 0,1,1,2,1,0) 
#   # Native::SET_CAM_ACTIVE(cam, true)

#   puts "cam: #{camera}"

#   line(camera)
#   # rotate(camera)

# end