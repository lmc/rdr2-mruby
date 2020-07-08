


RDR2.script(:menu) do

  class Menu
    CALLBACKS = [:action_primary,:cancel,:up,:down,:left,:right]

    attr_accessor :items, :selected_index, :scroll_index, :scroll_limit, :coords
    
    def initialize(host_script,&block)
      @host_script = host_script
      @callbacks = Callbacks.new( self )
      @callbacks.register( *Menu::CALLBACKS )

      # override here since @callbacks registers `trigger!` at runtime on us
      # trigger callbacks for selected menu item first, then any of our own
      def self.trigger!(event,*args,&block)
        # DEBUG "Menu trigger! - #{selected_item.inspect}"
        selected_item.trigger!(event,*args,&block)
        @callbacks.trigger!(event,*args,&block)
      end

      @items = []
      @selected_index = 0
      @scroll_index = 0
      @scroll_limit = 12
      @coords = { x: 0.04 , y: 0.055 , w: 0.25 , h: 0.5 , ih: 0.04 , ts: 0.4 , tpx: 0.005, tpy: 0.005 }
      yield(self) if block_given?
    end



    def adjust_selected_index!(delta = 0)
      @selected_index += delta

      @selected_index = 0 if @selected_index < 0
      @selected_index = @items.size - 1 if @selected_index > @items.size - 1

      if @selected_index >= @scroll_index + @scroll_limit
        @scroll_index = @selected_index - @scroll_limit + 1
      end

      if @selected_index < @scroll_index
        @scroll_index = @selected_index
      end

      @scroll_index = 0 if @scroll_index < 0

      # DEBUG "@selected_index: #{@selected_index}, @scroll_index: #{@scroll_index}, @scroll_limit: #{@scroll_limit}"
    end

    def draw!
      coords = @coords.dup
      @items[ (@scroll_index)...(@scroll_index+@scroll_limit) ].each_with_index do |item,index|
        selected = @selected_index == @scroll_index + index
        h = item.draw!(coords,selected)
        coords[:y] += h
      end
    end

    def selected_item
      @items[@selected_index]
    end

    def item(type,options,&block)
      @items << MenuItem.new(type,options,&block)
    end
    [:text].each do |type|
      define_method(type){|options,&block| self.item(type,options,&block) }
    end
    
  end

  class MenuItem

    attr_accessor :type, :options

    def initialize(type,options,&block)
      @type = type
      @options = options
      @callbacks = Callbacks.new( self )
      @callbacks.register( *Menu::CALLBACKS )
      yield(self) if block_given?
    end

    def draw!(coords,selected)
      rgba = selected ? [32,244,32,127] : [0,0,0,127]
      Native::DRAW_RECT( coords[:x]+(coords[:w]/2) , coords[:y]+(coords[:ih]/2) , coords[:w] , coords[:ih] , *rgba, false, false )
      text = option(:value)
      RDR2.draw_text( coords[:x]+coords[:tpx] , coords[:y]+coords[:tpy] , coords[:ts],coords[:ts], 255,255,255,255 , text )
      return coords[:ih]
    end

    def option(name)
      @options[name].respond_to?(:call) ? @options[name].call : @options[name]
    end
  end

  @menus = {}
  @menus_visible = {}
  @menus_focus = nil

  def menu(name,options = {},&block)
    @menus[name] = Menu.new( self , &block )
  end

  def show_and_focus!(name)
    self.hide_all!
    self.show(name)
    self.focus(name)
  end

  def show(name)
    @menu_visible = true
    @menus_visible[name] = true
  end

  def focus(name)
    @menus_focus = name
  end

  def hide(name)
    @menus_visible.delete(name)
    @menus_focus = nil if @menus_focus == name
    @menu_visible = false if @menus_visible.size == 0
  end

  def hide_all!
    @menus_visible.each{|m,_| self.hide(m) }
  end

  def focused_menu
    @menus[@menus_focus]
  end

  def focused_menu_item
    menu = focused_menu
    return nil if !menu
    menu.items[menu.selected_index]
  end

  def disabled_pad_released?(name)
    Native::IS_DISABLED_CONTROL_JUST_RELEASED(0,Native::GET_HASH_KEY(name))
  end

  def check_pad!
    @menu_visible ||= false
    Native::DISABLE_CONTROL_ACTION(0,1644850270,true) # select
    Native::_ANIMATE_GAMEPLAY_CAM_ZOOM(3.0,8.0)
    Native::_DISABLE_FIRST_PERSON_CAM_THIS_FRAME()

    if @menu_visible

      Native::DISABLE_ALL_CONTROL_ACTIONS(0)

      if focused_menu
        if disabled_pad_released?("INPUT_FRONTEND_UP")
          # TODO: listen to `up` event
          focused_menu.adjust_selected_index!(-1)
        end
        if disabled_pad_released?("INPUT_FRONTEND_DOWN")
          # TODO: listen to `down` event
          focused_menu.adjust_selected_index!(+1)
        end
        if disabled_pad_released?("INPUT_FRONTEND_LEFT")
          focused_menu.trigger!(:left)
        end
        if disabled_pad_released?("INPUT_FRONTEND_RIGHT")
          focused_menu.trigger!(:right)
        end
        if disabled_pad_released?("INPUT_FRONTEND_ACCEPT")
          focused_menu.trigger!(:action_primary)
        end
        if disabled_pad_released?("INPUT_FRONTEND_CANCEL")
          focused_menu.trigger!(:cancel)
        end
      end

    else

    end

    if Native::IS_DISABLED_CONTROL_JUST_RELEASED(0,1644850270) # select
      if @menu_visible
        RDR2[:menu].hide_all!
        # @menu_visible = false
      else
        # Native::DISABLE_CONTROL_ACTION(0,613911080,true) # dpad up
        # Native::DISABLE_CONTROL_ACTION(0,184129944,true) # dpad left
        # Native::DISABLE_CONTROL_ACTION(0,1141111167,true) # dpad down
        # Native::DISABLE_CONTROL_ACTION(0,1287709438,true) # dpad down
        # Native::DISABLE_CONTROL_ACTION(0,1367437629,true) # x
        # Native::DISABLE_CONTROL_ACTION(0,648122183,true) # circle
        # @menu_visible = true
        RDR2[:menu].show_and_focus!(:test)
      end
    end
  end

  loop do
    @menus_visible.each_pair do |name,_|
      @menus[name].draw!
    end
    check_pad!
    wait(0)
  end

end




RDR2.script(:menu_test) do
  wait(0)


  RDR2[:menu].menu(:test) do |menu|

    menu.text( value: 'Reload' ) do |item|
      item.on :action_primary do
        RDR2.reload_next_tick!
      end
    end


    menu.text( value: 'Swap character model' ) do |item|
      item.on :action_primary do
        RDR2[:menu].show_and_focus!(:swap_character_model)
      end
    end

    menu.text( value: 'Weather' ) do |item|
      item.on :action_primary do
        RDR2[:menu].show_and_focus!(:weather)
      end
    end

    menu.text( value: 'Time' ) do |item|
      item.on :action_primary do
        RDR2[:menu].show_and_focus!(:time)
      end
    end

    menu.text( value: 'Teleport to waypoint' ) do |item|
      item.on :action_primary do
        dest = Native::_GET_WAYPOINT_COORDS()
        if dest.nonzero?
          RDR2[:trainer].safe_player_teleport!( *dest )
        end
      end
    end

    menu.text( value: 'Save window coords' ) do |item|
      item.on :action_primary do
        RDR2[:dev_workspace].save_current_coords!
      end
    end


    menu.text( value: '3-star everything' ) do |item|
      item.on :action_primary do
        RDR2.world_get_all_peds.each do |ped|
          if !Native::IS_PED_HUMAN(ped)
            Native::_0x8B6F0F59B1B99801(ped,2)
          end
        end
      end
    end

    menu.text( value: '1-star everything' ) do |item|
      item.on :action_primary do
        RDR2.world_get_all_peds.each do |ped|
          if !Native::IS_PED_HUMAN(ped)
            Native::_0x8B6F0F59B1B99801(ped,0)
          end
        end
      end
    end


  end


  RDR2[:menu].menu(:swap_character_model) do |menu|

    values = ['player_zero'] + MODEL_FILENAMES
    values.each do |value|
      menu.text( value: value ) do |item|
        item.on :action_primary do
          RDR2[:trainer].swap_char_model(value)
        end
      end
    end

  end


  RDR2[:menu].menu(:weather) do |menu|

    values = [
      "Blizzard",
      "Clouds",
      "Drizzle",
      "Fog",
      "GroundBlizzard",
      "Hail",
      "HighPressure",
      "Hurricane",
      "Misty",
      "Overcast",
      "OvercastDark",
      "Rain",
      "Sandstorm",
      "Shower",
      "Sleet",
      "Snow",
      "SnowClearing",
      "SnowLight",
      "Sunny",
      "Thunder",
      "Thunderstorm",
      "WhiteOut" 
    ]
    values.each do |value|
      menu.text( value: value ) do |item|
        item.on :action_primary do
          Native::_SET_WEATHER_TYPE( Native::GET_HASH_KEY(value) , true , true , false , 0.0 , false)
        end
      end
    end

  end


  RDR2[:menu].menu(:time) do |menu|

    values = (0..23).to_a
    values.each do |value|
      menu.text( value: "#{value.to_s.rjust(2,"0")}:00" ) do |item|
        item.on :action_primary do
          Native::SET_CLOCK_TIME(value,0,0)
        end
      end
    end

  end


end

