# THERE ARE PROBLEMS WITH UPVALUES
I don't fully understand luajit bytecode, so using upvalues is broken :X Make a PR if you have a fix for this [function](https://github.com/Srlion/lua_obfuscator/blob/41d683e75c9f3a8843acb2909572a94dc5903873/main.lua#L711)!
# glua_obfuscator
This is more like a bytecode converter: lua code -> gluajit bytecode -> lua code

There are lots of stuff that is taken from many sources that I can't remember because this was just a private thing that I was working on.

How to use:
luajit main.lua INPUTFILE OUTPUTFILE (Optional)USE_UTF8

Credits:

* [Lapin](https://github.com/ExtReMLapin) for libs/dis_bc.lua
* https://github.com/everyday-as/gluac

You can tell me if you find a part of code that is used from someone so I can give them credits.
