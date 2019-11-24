
# uncomment to enable logs in console window
# RDR2.create_console_window!

# initialise main script scheduler
RDR2.scripts_init!

# load .rb files from RDR2/scripts/rdr2-mruby/scripts/
$scripts_count = 0
RDR2.dir_glob("scripts","*.rb") do |path|
  begin
    OUT "[init.rb] loading #{path}"
    load(path)
    $scripts_count += 1
  rescue => ex
    error_report!(ex,"init.rb")
  end
end

RDR2.script(:welcome) do
  text = "[github.com/lmc/rdr2-mruby] [runtime v#{RUNTIME_VERSION}, mruby v#{MRUBY_VERSION}] loaded #{$scripts_count} scripts"
  notification_script(text,5)
end

# tick scheduler each frame
def RDR2.tick!
  RDR2.scripts_tick!
end
