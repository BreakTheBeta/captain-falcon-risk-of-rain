import ctypes,ctypes.util,sys
l=ctypes.CDLL(ctypes.util.find_library('lua5.4') or 'liblua5.4.so.0');l.luaL_newstate.restype=ctypes.c_void_p
p=l.luaL_newstate();l.luaL_openlibs.argtypes=[ctypes.c_void_p];l.luaL_openlibs(p)
l.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p];l.luaL_loadfilex.restype=ctypes.c_int
l.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p];l.lua_pcallk.restype=ctypes.c_int
l.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];l.lua_tolstring.restype=ctypes.c_char_p
err=l.luaL_loadfilex(p,sys.argv[1].encode(),None) or l.lua_pcallk(p,0,-1,0,0,None)
if err:print(l.lua_tolstring(p,-1,None).decode());sys.exit(1)
