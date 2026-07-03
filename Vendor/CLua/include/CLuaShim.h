/*
 * CLuaShim.h — KiwiDesk addition (not part of upstream Lua).
 *
 * Swift cannot import C function-like macros. This header wraps
 * the macros the Swift bridge needs as static inline functions
 * and re-exports macro constants as typed constants.
 */
#ifndef CLUA_SHIM_H
#define CLUA_SHIM_H

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static const int SHIM_LUA_REGISTRYINDEX = LUA_REGISTRYINDEX;
static const int SHIM_LUA_MULTRET = LUA_MULTRET;
static const int SHIM_LUA_MASKCOUNT = LUA_MASKCOUNT;
static const int SHIM_LUA_OK = LUA_OK;
static const int SHIM_LUA_TNIL = LUA_TNIL;
static const int SHIM_LUA_TBOOLEAN = LUA_TBOOLEAN;
static const int SHIM_LUA_TNUMBER = LUA_TNUMBER;
static const int SHIM_LUA_TSTRING = LUA_TSTRING;
static const int SHIM_LUA_TTABLE = LUA_TTABLE;
static const int SHIM_LUA_TFUNCTION = LUA_TFUNCTION;
static const int SHIM_LUA_NOREF = LUA_NOREF;

static inline void shim_lua_pop(lua_State *L, int n) {
    lua_pop(L, n);
}

static inline void shim_lua_newtable(lua_State *L) {
    lua_newtable(L);
}

static inline const char *shim_lua_tostring(lua_State *L,
                                            int idx) {
    return lua_tostring(L, idx);
}

static inline lua_Number shim_lua_tonumber(lua_State *L,
                                           int idx) {
    return lua_tonumber(L, idx);
}

static inline lua_Integer shim_lua_tointeger(lua_State *L,
                                             int idx) {
    return lua_tointeger(L, idx);
}

static inline int shim_lua_pcall(lua_State *L, int nargs,
                                 int nresults, int errfunc) {
    return lua_pcall(L, nargs, nresults, errfunc);
}

static inline void shim_lua_pushcfunction(lua_State *L,
                                          lua_CFunction f) {
    lua_pushcfunction(L, f);
}

static inline int shim_lua_upvalueindex(int i) {
    return lua_upvalueindex(i);
}

static inline int shim_lua_isfunction(lua_State *L, int idx) {
    return lua_isfunction(L, idx);
}

static inline int shim_lua_istable(lua_State *L, int idx) {
    return lua_istable(L, idx);
}

static inline int shim_lua_isnil(lua_State *L, int idx) {
    return lua_isnil(L, idx);
}

static inline int shim_luaL_dostring(lua_State *L,
                                     const char *s) {
    return luaL_dostring(L, s);
}

static inline void shim_luaL_openlibs(lua_State *L) {
    luaL_openlibs(L);
}

/*
 * Timeout sandbox: a monotonic deadline is stored in the
 * state's extra space (LUA_EXTRASPACE == sizeof(void*), which
 * fits a double). The count hook raises a Lua error once the
 * deadline passes. The whole mechanism lives in C because
 * luaL_error longjmps, which must not unwind Swift frames.
 */
#include <time.h>

static inline double shim_monotonic_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static inline void shim_set_deadline(lua_State *L, double d) {
    *(double *)lua_getextraspace(L) = d;
}

static void shim_timeout_hook(lua_State *L, lua_Debug *ar) {
    (void)ar;
    double deadline = *(double *)lua_getextraspace(L);
    if (deadline > 0 && shim_monotonic_now() > deadline) {
        luaL_error(L, "KiwiDesk: Lua callback timed out");
    }
}

/* Checks the deadline every `count` VM instructions. */
static inline void shim_enable_timeout_hook(lua_State *L,
                                            int count) {
    shim_set_deadline(L, 0);
    lua_sethook(L, shim_timeout_hook, LUA_MASKCOUNT, count);
}

#endif /* CLUA_SHIM_H */
