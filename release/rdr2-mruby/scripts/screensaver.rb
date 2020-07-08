
# RDR2.script(:screensaver) do
#   @ped = nil
#   @camera = nil

#   def create_camera!
#     @camera = Native::CREATE_CAMERA(26379945, false)
#     Native::SET_CAM_PARAMS(@camera, 0.0, 0.0, 0.0, -5.0428, 0.3271, 44.1289, 47.8478, 0, 1, 1, 2, 0, 0)
#     @camera
#   end

#   def enable_camera!
#     Native::SET_CAM_ACTIVE(@camera, true)
#     Native::RENDER_SCRIPT_CAMS(true, false, 3000, true, false, 0)
#   end

#   def disable_camera!
#     Native::SET_CAM_ACTIVE(@camera, false)
#     Native::RENDER_SCRIPT_CAMS(false, false, 3000, true, false, 0)
#   end

#   def set_and_aim_camera!( coords , target )
#     # Native::SET_CAM_COORD(@camera,*coords)
#     Native::POINT_CAM_AT_COORD(@camera,*target)
#     Native::SET_HD_AREA(*target,100.0)
#   end

#   def get_ped!
#     all = RDR2.world_get_all_peds
#     result = nil

#     me_coords = Native::GET_ENTITY_COORDS(Native::PLAYER_PED_ID(),false,false)
#     loop do
#       result = all.sample
#       return result if Native::GET_ENTITY_COORDS(result,false,false).z > me_coords.z + 20.0
#     end
#   end


#   # wait(60_000)
  
#   loop do

#     if !@camera
#       @camera = create_camera!
#       enable_camera!
#     end

#     if !@ped || Native::IS_ENTITY_DEAD(@ped)
#       @ped = get_ped!
#       INFO "@ped: #{@ped}"
#       Native::ATTACH_CAM_TO_ENTITY(@camera, @ped, 0.0 , -5.0 , 2.0 , true)
#       Native::SET_FOCUS_ENTITY(@ped)
#     end

#     Native::HIDE_HUD_AND_RADAR_THIS_FRAME()

#     coords = Native::GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS( @ped , 0.0 , -5.0 , 2.0 )
#     target = Native::GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS( @ped , 0.0 ,  5.0 , 0.0 )
#     set_and_aim_camera!( coords , target )

#     wait(0)
#   end
# end
