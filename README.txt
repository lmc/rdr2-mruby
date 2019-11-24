
Red Dead Redemption 2 MRuby Script Hook
=======================================

![RDR2 game running with Ruby script output in console window](rdr2-mruby.png)


Overview
--------

This mod provides an MRuby VM and native function bindings to allow you to write game scripts for Red Dead Redemption 2 using Ruby.



Installation
------------

1. Install RedHook2 from https://github.com/DottieDot/RedHook2/releases

2. Create a folder named 'scripts' in the RDR2 game folder, if it does not already exist.

3. Copy the contents of the 'release' folder into the 'Red Dead Redemption 2/scripts' folder. This should leave you with 'rdr2-mruby.asi' and the 'rdr2-mruby' sub-folder inside the scripts folder.

4. Use RedHook2's loader.exe, then launch the game through the Rockstar Games Launcher.

5. Upon loading a saved game, the Ruby scripts should start running, with a status message displayed at the top of the screen by default.



Troubleshooting
---------------

If you're not seeing the status message after loading the game, or you're getting other warnings or crashes, you can enable the debug console for more error information.

Open 'Red Dead Redemption 2/scripts/rdr2-mruby/init.rb' and uncomment the line 'RDR2.create_console_window!', and save it.

If you encounter any crashes, please report them to the Github issue tracker: https://github.com/lmc/rdr2-mruby/issues



Writing your own scripts
------------------------

The MRuby Script hook will load any .rb file found in 'Red Dead Redemption 2/scripts/rdr2-mruby/scripts'

Native game functions are defined under the `Native` module, and are called by name without the namespace included. ie. `Entity::GET_ENTITY_COORDS` would be called from Ruby like `Native::GET_ENTITY_COORDS`. A list of native functions and their arguments are available at https://unknownmodder.github.io/rdr3-native-db/

Arguments and return values will generally be standard Ruby objects, with handles and pointers to game objects returned as Ruby Fixnums. For the handful of native functions that use reference arguments, a `Native::Reference` class has been provided which can be passed into a native function, then cast it's result back to a Ruby object. For examples, see scripts/coords.rb

Here is a recommended boilerplate example script, to demonstrate the structure:

```
# define script to be executed in the block body 
RDR2.script(:draw) do

  # do any one-off initialisation code here
  pressed = false

  # begin an infinite loop that'll loop once per frame
  loop do

    # do anything once per frame here, like check input,
    # draw to the screen, run other native functions
    pressed = RDR2.key_just_up(0x7A)
    if pressed

      # call native game functions under the Native module/namespace
      player_ped = Native::GET_PLAYER_PED(0)
      Native::SET_ENTITY_COORDS(player_ped,123.0,456.0,50.0,false,false,false,false)

    end

    # wait here for a specified number of seconds (0ms = run every frame)
    # (implemented as coroutines, use `wait(nil)` to exit script)
    wait(0)

  # infinite loop never exits unless exception is raised or nil is yielded
  end

end
```


Licence
-------

Copyright Luke Mcildoon 2019, licensed under the MIT License.

