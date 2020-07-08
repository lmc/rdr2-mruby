
RDR2.script(:coords) do
  loop do
    # get the player's Ped so we can use it with Entity functions
    player_ped = Native::GET_PLAYER_PED(0)

    # get coords as a Vector3, and angle as a float
    player_coords = Native::GET_ENTITY_COORDS(player_ped,0,0)
    player_angle = Native::GET_ENTITY_HEADING(player_ped)

    # use reference objects to get the z coordinate and normal under the player
    r1 = Reference.new
    r2 = Reference.new
    Native::GET_GROUND_Z_AND_NORMAL_FOR_3D_COORD(*player_coords,r1,r2)
    gz = r1.float
    gn = r2.vector3

    # draw box and text in top-right corner of the screen
    Native::DRAW_RECT(0.875, 0.04, 0.25, 0.08, 0, 0, 0, 192, false, false)

    text = [
      "x: #{'%.3f' % player_coords.x}", 
      "y: #{'%.3f' % player_coords.y}",
      "z: #{'%.3f' % player_coords.z}",
      "r: #{'%.3f' % player_angle}"
    ].join(" , ")
    RDR2.draw_text(0.755,0.0075,0.342,0.342,255,255,255,255,text)

    text = [
      "ground z: #{'%.3f' % gz}",
      "normal: #{'%.3f' % gn.x} , #{'%.3f' % gn.y} , #{'%.3f' % gn.z}"
    ].join(" , ")
    RDR2.draw_text(0.755,0.04+0.0075,0.342,0.342,255,255,255,255,text)

    # yield control of this script for a wait time of zero milliseconds
    # ie. we want to run again ASAP, so we'll get to run every frame
    wait(0)
  end
end
