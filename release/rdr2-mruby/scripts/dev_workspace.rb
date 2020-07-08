
class Database

  attr_accessor :keys
  attr_accessor :default_values

  def initialize( path , &block )
    @path = path
    @keys = []
    @values = {}
    @default_values = {}
    yield(self)
  end

  def key( name , default_value = nil , &block )
    @keys << name
    @default_values[ name ] = default_value
  end

  def load!
    INFO "loading database from #{@path}"
    File.open(@path,"r") do |f|
      @values = eval( f.read )
    end
  rescue => ex
    WARN ex.message
    nil
  end

  def save!
    INFO "saving database to #{@path}"
    File.open(@path,"w") do |f|
      f.puts "{"
      longest_key = @keys.map{|k| k.inspect.size}.max
      @keys.each do |key|
        value = @values[key] || @default_values[key]
        f.puts "  #{key.inspect.ljust(longest_key,' ')} => #{value.inspect},"
      end
      f.puts "}"
    end
  end

  def get( name )
    @values[ name ]
  end

  def set( name , value )
    @values[ name ] = value
  end

  def update( hash )
    hash.each_pair do |key,value|
      self.set(key,value)
    end
    self.save!
  end

end

RDR2.script(:dev_workspace) do

  @config = Database.new("./rdr2-mruby/config/dev_workspace.rb") do |db|
    db.key( :preferred_console_coords , nil )
    db.key( :preferred_game_coords    , nil )
    db.load!
  end

  def save_current_coords!
    console_coords = RDR2.get_console_window_coords
    gamewin_coords = RDR2.get_game_window_coords
    @config.update( preferred_console_coords: console_coords )
    @config.update( preferred_game_coords: gamewin_coords )
  end

  preferred_console_coords = [-2513,759,591,804]
  preferred_gamewin_coords = [-3212,4,1296,759]

  # RDR2.set_console_window_coords( *preferred_console_coords , 0 )
  # RDR2.set_game_window_coords( *preferred_gamewin_coords , 0 )

  last_console_coords = nil
  last_console_time = nil
  last_gamewin_coords = nil
  last_gamewin_time = nil

  console_coords = RDR2.get_console_window_coords
  gamewin_coords = RDR2.get_game_window_coords

  if @config.get( :preferred_console_coords ) && console_coords != @config.get( :preferred_console_coords )
    INFO "setting preferred console window coords..."
    # RDR2.set_console_window_coords( *@config.get( :preferred_console_coords ) , 0 )
  end

  if @config.get( :preferred_game_coords ) && gamewin_coords != @config.get( :preferred_game_coords )
    INFO "setting preferred game window coords..."
    # RDR2.set_game_window_coords( *@config.get( :preferred_game_coords ) , 0 )
  end


  loop do
    console_coords = RDR2.get_console_window_coords
    gamewin_coords = RDR2.get_game_window_coords

    if last_console_coords != console_coords
      last_console_time = Time.now
      last_console_coords = console_coords
    end
    if last_console_time && last_console_time < Time.now - 1
      last_console_time = nil
      OUT "[dev_workspace.rb] console: #{console_coords.inspect}"
      # @config.update( preferred_console_coords: console_coords )
    end

    if last_gamewin_coords != gamewin_coords
      last_gamewin_time = Time.now
      last_gamewin_coords = gamewin_coords
    end
    if last_gamewin_time && last_gamewin_time < Time.now - 1
      last_gamewin_time = nil
      OUT "[dev_workspace.rb] game: #{gamewin_coords.inspect}"
      # @config.update( preferred_game_coords: gamewin_coords )
    end

    wait(0)
  end

end
