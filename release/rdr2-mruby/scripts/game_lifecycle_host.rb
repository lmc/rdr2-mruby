
# manages game lifecycle callbacks, like game_start, game_save, game_load, etc.

RDR2.script(:game_lifecycle_host) do

  # rb1 = RingBuffer.new( 3 , nil )
  # OUT rb1.inspect
  # rb1 << "one"
  # OUT rb1.inspect
  # rb1 << "two"
  # OUT rb1.inspect
  # rb1 << "three"
  # OUT rb1.inspect
  # rb1 << "four"
  # OUT rb1.inspect

  OUT 'quot "test"'

  loop do

    wait(0)
  end
end
