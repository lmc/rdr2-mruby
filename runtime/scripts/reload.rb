
# also hardcoded to react to F12 in c code, that key can be used 
# as failsafe in case the mruby vm crashes globally to restart it
RDR2.script(:reload) do
  loop do
    if RDR2.key_just_up(0x7A) # F11
      RDR2.reload_next_tick!
    end
    wait(0)
  end
end
