
RDR2.library(:trainer) do

  def get_placement_coords( x, y, z )
    # zs = [ 200.0 , 100.0 , z , 0.0 , 300.0 , 400.0 , 500.0 , 600.0 , 800.0 , -100.0 ]
    zs = [ 100.0 , 150.0 , 200.0 , 250.0 , z , 0.0 , -50.0 , -100.0 , 300.0 , 350.0 , 400.0 , 450.0 , 500.0 , 550.0 , 600.0, 650.0, 700.0, 750.0, 800.0, 850.0, 900.0, 950.0, 1000.0 ]
    coords = Vector3.new( x, y, z )
    ref = Reference.new
    zs.each do |gz|
      coords.z = gz
      puts "testing: #{coords.inspect}"
      Native::REQUEST_COLLISION_AT_COORD( *coords )
      wait(250)
      if r = Native::GET_GROUND_Z_FOR_3D_COORD( *coords , ref , true )
        coords.z = ref.float
        puts "got: #{coords.inspect}"
        return coords
      end
    end
    return nil
  end

  def get_player_entity_for_teleport
    ent = Native::PLAYER_PED_ID()
    return [:mount, Native::GET_MOUNT(ent)] if Native::IS_PED_ON_MOUNT(ent)
    return [:ped, ent]
  end

  def safe_player_teleport!( x, y, z )
    type, ent = get_player_entity_for_teleport
    zoff = { mount: 1.5 , ped: 0.25 }[type]
    src = Native::GET_ENTITY_COORDS( ent , 0 , 0 )
    dest = Vector3.new(x,y,z)
    if dest.inject(:+) != 0.0
      Native::REQUEST_COLLISION_AT_COORD( *dest )
      Native::DO_SCREEN_FADE_OUT(500)
      wait(500)
      Native::SET_ENTITY_COORDS( ent , *dest , 0, 0, 1, 0 )
      wait(250)
      if dest = get_placement_coords( *dest )
        dest.z += zoff
        puts "setting to: #{dest.inspect}"
        Native::SET_ENTITY_COORDS( Native::PLAYER_PED_ID() , *dest , 0 , 0 , 1 , 0 )
        Native::SET_ENTITY_COORDS( ent , *dest , 0 , 0 , 1 , 0 )
      else
        Native::SET_ENTITY_COORDS( ent , *src , 0 , 0 , 1 , 0 )
      end
      Native::DO_SCREEN_FADE_IN(500)
      wait(500)
    end
  end

  def pointer_search(addr, size, value, pack = nil)
    data = RDR2.memory_read(addr , size )
    idx = data.index( pack ? [value].pack(pack) : value )
    idx ? Pointer.new( addr + idx ) : nil
  end

  @global_ptr_1 = nil
  @global_ptr_2 = nil
  def swap_char_model(model_new)
    model_current = Native::GET_ENTITY_MODEL( Native::PLAYER_PED_ID() )

    # no need to request/release new model unlike normal model swaps
    model_new ||= "A_C_HAWK_01"
    model_new = model_new.is_a?(String) ? Native::GET_HASH_KEY(model_new) : model_new

    @global_ptr_1 ||= pointer_search( RDR2.get_global_pointer(0)               , 4096 , model_current , "Q" )
    @global_ptr_2 ||= pointer_search( RDR2.get_global_pointer(0x1D890E) - 2048 , 4096 , model_current , "Q" )

    @global_ptr_1.integer = model_new
    @global_ptr_2.integer = model_new

    # wait while model loading/swapping happens by the engine
    wait(0) until Native::GET_ENTITY_MODEL( Native::PLAYER_PED_ID() ) == model_new

    # make new model visible once swapped
    Native::_0x283978A15512B2FE( Native::PLAYER_PED_ID() , true )
  end


  # def check_pad!
  #   coords = { x: 0.5 , y: 0.01 , w: 0.1 , ih: 0.02 , ts: 0.3 , tpx: 0.001, tpy: 0.001 }
  #   slices = PAD_HASHES.each_slice(64).to_a
  #   slices[4].each do |hash|
  #     text = "#{hash}: #{Native::IS_DISABLED_CONTROL_PRESSED(2,hash) ? '!!!' : '   '}"
  #     h = MenuItem.new(:text,{ value: text }).draw!(coords)
  #     coords[:y] += h
  #     if coords[:y] > 0.95
  #       coords[:y] = 0.01
  #       coords[:x] += coords[:w]
  #     end
  #   end
  # end


  # Native::SET_MAPDATACULLBOX_ENABLED("Win_Intro", false)
  # Native::SET_MAPDATACULLBOX_ENABLED("Main_World", true)
  # Native::SET_MAPDATACULLBOX_ENABLED("Beaver Hollow", true)

  # Native::_REQUEST_IMAP(-78801135);
  # Native::_REQUEST_IMAP(-591921971);

  # Native::SET_ENTITY_COORDS( Native::PLAYER_PED_ID() , -1775.68, 2758.13, 598.95 , 1 , 1 , 1 , 1 )

  # Native::SET_MAPDATACULLBOX_ENABLED("Guarma_Boat", true)
  # Native::_SET_SNOW_COVERAGE_TYPE(1)

  Native::SET_CLOCK_TIME(12,0,0)

  # swap_char_model("A_C_COW")
  swap_char_model("A_C_HAWK_01")

  loop do

    if Native::IS_ENTITY_DEAD( Native::PLAYER_PED_ID() ) && @need_to_reset_char_model
      INFO "resetting char model on death to player_zero"
      swap_char_model("player_zero")
      @need_to_reset_char_model = false
    elsif !@need_to_reset_char_model
      INFO "debouncing char model reset, waiting for player death"
      @need_to_reset_char_model = true
      wait(100)
    end

    # Native::_0xC63540AEF8384732(16.95, 50.04, 1, 1.15, 1.28, -1082130432, 1.86, 8.1, 1)
    Native::_0xC63540AEF8384732(0.0, 50.04, 1, 1.15, 1.28, -1082130432, 1.86, 8.1, 1)

    RDR2.world_get_all_peds.each do |ped|
      Native::_0x7528720101A807A5(ped,2)
      # if !Native::IS_PED_HUMAN(ped) && !Native::IS_ENTITY_DEAD(ped)
      # if !Native::IS_ENTITY_DEAD(ped)

      #   # if Native::_IS_MOUNT_SEAT_FREE(ped,0)
      #     Native::START_ENTITY_FIRE(ped, 1.0, -1, 14)
      #   # end

      #   # Native::SET_ANIMAL_TUNING_FLOAT_PARAM(ped,74,1.0) # animal aggression ?
      #   # Native::SET_ANIMAL_TUNING_FLOAT_PARAM(ped,112,0.0) # 
      #   # Native::_0x408D1149C5E39C1E(ped,2)
      #   # Native::_0x6C57BEA886A20C6B(ped,2)
      #   # Native::_0x1520626FFAFFFA8F(ped,2)
      #   # Native::_0x2DF3D457D86F8E57(ped,2)
      # end
    end

    # dest = Native::_GET_WAYPOINT_COORDS()
    # if dest.nonzero?
    #   safe_player_teleport!( *dest )
    # end

    # ent = get_player_entity_for_teleport
    # src = Native::GET_ENTITY_COORDS( ent , 0 )
    # dest = Native::_GET_WAYPOINT_COORDS()
    # if dest.inject(:+) != 0.0
    #   puts "waypoint: #{dest.inspect}"
    #   Native::REQUEST_COLLISION_AT_COORD( *dest )
    #   Native::DO_SCREEN_FADE_OUT(500)
    #   wait(500)
    #   Native::SET_ENTITY_COORDS( ent , *dest , 1 , 1 , 1 , 1 )
    #   wait(250)
    #   if dest = get_placement_coords( *dest )
    #     Native::SET_ENTITY_COORDS( ent , *dest , 1 , 1 , 1 , 0 )
    #   else
    #     Native::SET_ENTITY_COORDS( ent , *src , 0 , 0 , 0 , 0 )
    #   end
    #   Native::DO_SCREEN_FADE_IN(500)
    #   wait(500)
    # end

    wait(0)
  end

end
