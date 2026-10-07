const std = @import("std");
const init = @import("init.zig");
const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
});
const build_options = @import("build_options");

const Lua = struct {
    const Self = @This();
    state: ?*c.lua_State,

    fn init() !Self {
        const newState = c.luaL_newstate() orelse return error.LuaStateCreationFailed;
        c.luaL_openlibs(newState);
        return Self{ .state = newState };
    }

    fn deinit(self: *Self) void {
        c.lua_close(self.state);
        self.state = null;
    }

    fn printLuaError(self: *const Self, kind: []const u8) void {
        const error_msg = c.luaL_tolstring(self.state, -1, null);
        defer c.lua_pop(self.state, 1);

        if (error_msg != null) {
            std.debug.print("lua: {s} error: {s}\n", .{ kind, error_msg });
        } else {
            std.debug.print("lua: {s} error: [unknown]\n", .{kind});
        }
    }

    fn runString(self: *const Self, string: [*c]const u8) !void {
        if (c.luaL_loadstring(self.state, string) != c.LUA_OK) {
            printLuaError(self, "load");
            return error.LuaExecutionFailed;
        }
        if (c.lua_pcallk(self.state, 0, c.LUA_MULTRET, 0, 0, null) != c.LUA_OK) {
            printLuaError(self, "runtime");
            return error.LuaExecutionFailed;
        }
    }

    fn addToPath(
        self: *const Self,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !void {
        _ = c.lua_getglobal(self.state, "package");
        _ = c.lua_getfield(self.state, -1, "path");
        const cur_path = c.lua_tolstring(self.state, -1, null);
        const new_path = try std.fmt.allocPrint(
            allocator,
            "{s};{s}",
            .{ cur_path, path },
        );
        c.lua_pop(self.state, 1);
        _ = c.lua_pushlstring(self.state, new_path.ptr, new_path.len);
        c.lua_setfield(self.state, -2, "path");
        c.lua_pop(self.state, 1);
    }

    fn preloadLib(
        self: *const Self,
        name: [*c]const u8,
        func: c.lua_CFunction,
    ) void {
        c.luaL_requiref(self.state, name, func, 1);
        c.lua_pop(self.state, 1);
    }
};

pub fn main() !void {
    var lua = try Lua.init();
    defer lua.deinit();

    const loader = init.Lua.new(@ptrCast(lua.state));
    try loader.preloadAll();

    //-------------------- lua alone
    const code =
        \\print("✔ lua")
    ;
    try lua.runString(code);

    //-------------------- lpeg
    const lpeg_code =
        \\-- example from https://www.inf.puc-rio.br/~roberto/lpeg/#ex
        \\-- matches a word followed by end-of-string
        \\local lpeg = require("lpeg")
        \\p = lpeg.R"az"^1 * -1
        \\
        \\assert(p:match("hello") == 6)
        \\assert(lpeg.match(p, "hello") == 6)
        \\assert(p:match("1 hello") == nil)
        \\print("✔ lpeg")
    ;
    try lua.runString(lpeg_code);

    //-------------------- basexx
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try lua.addToPath(allocator, build_options.lua_path);
    const basexx_code =
        \\basexx = require("basexx")
        \\local value = basexx.to_base64("✔ basexx")
        \\print(basexx.from_base64(value))
    ;
    try lua.runString(basexx_code);

    //-------------------- fifo
    const fifo_code =
        \\fifo = require("fifo")
        \\local f = fifo()
        \\f:push("✔ fifo")
        \\result, _ = f:peek()
        \\print(result)
    ;
    try lua.runString(fifo_code);

    //-------------------- cqueues
    const cqueues_code =
        \\local cqueues = require("cqueues")
        \\local cq = cqueues.new()
        \\cq:wrap(function() print("✔ cqueues") end)
        \\assert(cq:loop())
    ;
    try lua.runString(cqueues_code);

    //-------------------- luaossl
    const luaossl_code =
        \\openssl_digest = require("openssl.digest")
        \\local digest = openssl_digest.new("sha256")
        \\digest:update("✔ openssl")
        \\local result = basexx.to_base64(digest:final())
        \\if(result == "Jiw9h0RdwAVukA5emBHZby0MYTRGD2NCYwr+cZMDhko=") then
        \\  print("✔ openssl")
        \\end
    ;
    try lua.runString(luaossl_code);
}
