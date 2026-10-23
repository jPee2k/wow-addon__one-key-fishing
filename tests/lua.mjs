// A small wrapper around fengari (Lua 5.3 in JavaScript), so the tests can run the addon's Lua without a game.
import fengari from "fengari";

const { lua, lauxlib, lualib, to_luastring } = fengari;

export function newState() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  return L;
}

// The error value on top of the stack as text, whatever its type; pops it.
function popError(L) {
  lauxlib.luaL_tolstring(L, -1); // pushes the value converted like tostring()
  const message = lua.lua_tojsstring(L, -1);
  lua.lua_pop(L, 2); // the converted string and the error value
  return message;
}

// Runs a chunk of Lua; throws with the Lua error message (and traceback) if it fails.
export function run(L, code, chunkName) {
  const buffer = to_luastring(code);
  if (lauxlib.luaL_loadbuffer(L, buffer, buffer.length, to_luastring(chunkName)) !== lua.LUA_OK) {
    throw new Error(popError(L));
  }
  lua.lua_getglobal(L, to_luastring("debug"));
  lua.lua_getfield(L, -1, to_luastring("traceback"));
  lua.lua_remove(L, -2);
  lua.lua_insert(L, -2); // traceback below the chunk, as the message handler
  const status = lua.lua_pcall(L, 0, 0, -2);
  if (status !== lua.LUA_OK) {
    const message = popError(L);
    lua.lua_pop(L, 1); // the traceback function
    throw new Error(message);
  }
  lua.lua_pop(L, 1);
}

export function setGlobalString(L, name, value) {
  lua.lua_pushstring(L, to_luastring(value));
  lua.lua_setglobal(L, to_luastring(name));
}

// Sets a global Lua array of strings.
export function setGlobalList(L, name, values) {
  lua.lua_createtable(L, values.length, 0);
  values.forEach((value, i) => {
    lua.lua_pushstring(L, to_luastring(value));
    lua.lua_rawseti(L, -2, i + 1);
  });
  lua.lua_setglobal(L, to_luastring(name));
}

export function getGlobalNumber(L, name) {
  lua.lua_getglobal(L, to_luastring(name));
  const value = lua.lua_tonumber(L, -1);
  lua.lua_pop(L, 1);
  return value;
}
