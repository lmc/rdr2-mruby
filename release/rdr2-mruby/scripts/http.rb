
RDR2.scheduler.on( :hook_end ) do
  RDR2.socket_close($server) if $server
end

class HttpRequest
  attr_accessor :raw, :method, :path, :query, :headers, :body

  def initialize(raw)
    if raw.is_a?(Numeric)
      # read error
      raw = "GET /__read_error_#{raw} HTTP/1.1\r\n\r\n\r\n"
    end
    self.raw = raw
    header, body = raw.split("\r\n\r\n")
    headers = header.split("\r\n")
    method_and_path = headers[0].gsub("HTTP/1.1","").split(" ",2)
    self.method = method_and_path[0]
    self.path, self.query = method_and_path[1].split("?",2)
    self.headers = Hash[ headers.map{|h| h.split(": ",2)} ]
    self.body = body
  end
end

class HttpServer
  attr_accessor :port, :socket_server, :routes
  attr_accessor :client, :request, :response
  attr_accessor :clients, :stats

  def initialize( port = nil , address = nil, backlog = nil , &block )
    port ||= 8000
    # address ||= "0.0.0.0"
    address ||= "127.0.0.1"
    backlog ||= 10
    self.port = port
    self.socket_server = RDR2.socket_listen(address,port,backlog)
    $server = self.socket_server
    self.routes = {}
    self.clients = {}
    self.stats = {
      requests: 0,
      statuses: Hash.new{|h,k| h[k] = 0},
      clients_this_frame: 0,
      bytes_read: 0,
      bytes_sent: 0,
    }
    yield(self) if block_given?
    # self.routes_finalise!
  end

  def route(method,paths,&block)
    paths.each do |path|
      self.routes[method] ||= []
      self.routes[method] << [path,block]
    end
  end

  def get(*paths,&block)
    self.route("GET",paths,&block)
  end

  EXTENSION_CONTENT_TYPES = {
    ".jpg" => "image/jpeg",
    ".bmp" => "image/bmp",
  }

  def file(path, content_type = nil)
    self.get(path) do
      self.serve_file(path,content_type)
    end
  end

  def dir(path, pattern = "*.*", content_type = nil)
    globdir = self.root_dir.gsub("./rdr2-mruby/","")
    globpath = globdir + path
    RDR2.dir_glob(globpath,pattern) do |filename|
      filename = filename.gsub("\\","/")
      filepath = filename.gsub(root_dir,"")
      self.file(filepath, content_type)
    end
  end

  def serve_file(path, content_type = nil)
    ext = File.extname(path)
    content_type ||= EXTENSION_CONTENT_TYPES[ext]
    fs_path = root_dir + path
    if File.exist?(fs_path)
      data = nil
      File.open(fs_path,"rb"){|f| data = f.read}
      [200,{"Content-Type": content_type}, data ]
    else
      [404,{"Content-Type": "text/plain"},"not found"]
    end
  end

  def root_dir
    "./rdr2-mruby/scripts/http"
  end

  def routes_finalise!
    self.routes.each_pair do |key,routeset|
      self.routes[key] = routeset.sort_by{|rs| rs[0].size }.reverse
    end
  end

  def output_routes!
    self.routes_finalise!
    self.routes.each_pair do |key,routeset|
      self.routes[key].each{|rs| OUT "[http.rb] #{key} #{rs[0]}"}
    end
  end

  def accept!
    while client = RDR2.socket_accept(self.socket_server)
      self.clients[ client ] = true
    end    
  end

  def serve_clients!
    self.clients.each_pair do |client,_|
      self.client = client
      read = RDR2.socket_read(client,-1,0)
      if read.is_a?(String)
        self.request = HttpRequest.new( read )
        rackup = self.route!(request)
        response = rackup_response(rackup)
        RDR2.socket_write(client,response)
        RDR2.socket_close(client)
        self.clients[ client ] = nil
        self.stats[:bytes_read] += read.size
        self.stats[:bytes_sent] += response.size
        self.stats[:requests]   += 1
        self.stats[:statuses][ rackup[0] ] += 1
      elsif read == 10035 # would block
        # do nothing now, check it again later
      end
    end
    self.clients.compact!
    nil
  end

  def route!(request)
    return [401,{},"no method"] if !self.routes[request.method]
    # puts "#{request.method} #{request.path}"
    self.routes[request.method].each do |routeset|
      prefix = routeset[0]
      if request.path[0...(prefix.size)] == prefix
        # puts "MATCH #{routeset[0]}"
        return routeset[1].call
      end
    end
    return [404,{},"not found"]
  end

  def run!
    self.routes_finalise!
    loop do
      RDR2.wait(0)
      self.accept!
      self.serve_clients!
      self.draw_status!(0.005,0.05,0.1,0.25,0.3,0.005,0.005)
    end
  end

  def draw_status!(x,y,w,h,ts,tpx,tpy)
    @status_addresses ||= begin
      RDR2.socket_addresses(&ya = YieldAccumulator.new)
      ya.values.join("\n")
    end
    text = "HTTP server\nport: #{self.port}\n#{@status_addresses}\n"
    text << (self.stats.keys - [:statuses]).map{|k| "#{k}: #{self.stats[k]}"}.join("\n") << "\n"
    text << self.stats[:statuses].map{|k,v| "#{k}: #{v}"}.join("\n") << "\n"
    Native::DRAW_RECT(x+(w/2), y+(h/2), w, h, 0, 0, 0, 192, false, false)
    RDR2.draw_text(x+tpx,y+tpy,ts,ts,255,255,255,255,text)
  end

  protected

  HTTP_STATUS_TEXT = {
    200 => "OK",
    404 => "Not Found"
  }
  def rackup_response(rackup)
    rackup[0] ||= 500
    rackup[1] ||= {}
    rackup[2] ||= ""
    rackup[1]["Connection"] = "close"
    response = ""
    response << "HTTP/1.1 #{rackup[0]}"
    response << " #{HTTP_STATUS_TEXT[rackup[0]]}\r\n"
    response << rackup[1].map{|k,v| "#{k}: #{v}"}.join("\r\n")
    response << "\r\n\r\n" + rackup[2]
  end

  def json_encode(obj)
    json = ""
    case obj
    when Array
      json << "["
      json << obj.map{|i| json_encode(i) }.join(",")
      json << "]"
    when Hash
      json << "{"
      json << obj.map{|k,v| "\"#{k.to_s.gsub('"','\\"')}\": #{json_encode(v)}" }.join(",")
      json << "}"
    when String
      json << "\"#{obj.inspect[1...-1].gsub('"','\\"')}\""
    when Symbol
      json << "\"#{obj.inspect}\""
    when Numeric
      json << obj.to_s
    when TrueClass, FalseClass
      json << obj.to_s
    when NilClass
      json << "null"
    else
      raise ArgumentError, "can't json_encode #{obj.inspect}"
    end
    json
  end

end

RDR2.script(:http) do
  @public = true # true: accessible over network , false: only accessible from localhost
  @port = 8001
  @backlog = 10

  RDR2.socket_init

  RDR2.socket_addresses(&ya = YieldAccumulator.new)

  bind_to = @public ? "0.0.0.0" : "127.0.0.1"
  addresses = @public ? ya.values[1..-1].join(', ') : "localhost"

  @server = HttpServer.new( @port , bind_to , @backlog ) do |http|

    http.get "/" , "/index" , "/index.html" do
      http.serve_file( "/assets/html/index.html" , "text/html" )
    end

    http.get "/app/map" do
      http.serve_file( "/assets/html/map.html" , "text/html" )
    end

    http.get "/app/logs.json" do
      data = LOGGER.buffer.array
      [ 200 , {"Content-Type": "text/json"} , http.json_encode(data) ]
    end

    http.get "/app/game.bmp" do
      [ 200 , {"Content-Type": "image/bmp"} , RDR2.game_window_bmp ]
    end

    http.get "/eval.json" do
      code = http.request.query
      data = {}
      begin
        data[:value] = eval( code )
        data[:inspect] = data[:value].inspect
        data[:success] = true
      rescue Exception => ex
        data[:error] = ex.message
        data[:success] = false
      end
      [ 200 , {"Content-Type": "text/json"} , http.json_encode(data) ]
    end

    http.get "/coords.json" do
      ped_data = ->(ped_id, tags = []){
        coords = Native::GET_ENTITY_COORDS( ped_id , false , false )
        heading = Native::GET_ENTITY_HEADING( ped_id )
        model = Native::GET_ENTITY_MODEL( ped_id )
        # tags << "model_" + model.to_s
        { id: ped_id, x: coords.x , y: coords.y , z: coords.z , r: heading , model: model , tags: tags.join(' ') }
      }
      data = RDR2.world_get_all_peds.map{ |ped_id| ped_data.call( ped_id , ['ped'] ) }
      data << ped_data.call( Native::PLAYER_PED_ID() , ['player'] )
      [ 200 , {"Content-Type": "text/json"} , http.json_encode(data) ]
    end

    http.get "/hashes.json" do
      hashes = MODEL_FILENAMES
      data = Hash[ hashes.map do |hash|
        [ Native::GET_HASH_KEY(hash) , hash ]
      end ]
      [ 200 , {"Content-Type": "text/json"} , http.json_encode(data) ]
    end

    http.get "/teleport" do
      coords = http.request.query.split(",").map(&:strip).map(&:to_f)
      Native::SET_ENTITY_COORDS( Native::PLAYER_PED_ID() , *coords , false )
      [ 200 , {"Content-Type": "text/plain"} , "OK" ]
    end

    http.get "/reload" do
      RDR2.reload_next_tick!
      [ 200 , {"Content-Type": "text/plain"} , "OK" ]
    end

    http.file "/assets/images/map0.jpg" , "image/jpeg"
    http.dir  "/assets/js" , "*.js"     , "text/javascript"

  end

  OUT "[http.rb] HTTP server running on port #{@port} on #{addresses}"
  @server.output_routes!
  @server.run!
end



















