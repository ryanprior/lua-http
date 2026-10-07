const std = @import("std");
const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
});
const build_options = @import("build_options");

extern fn luaopen_lpeg(state: ?*c.lua_State) c_int;

extern fn luaopen__cqueues(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_errno(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_thread(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_dns(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_socket(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_signal(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_notify(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_condition(state: ?*c.lua_State) c_int;
extern fn luaopen__cqueues_debug(state: ?*c.lua_State) c_int;

extern fn luaopen__openssl(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_bignum(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_cipher(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_compat(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_des(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_digest(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_ec_group(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_hmac(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_kdf(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_ocsp_basic(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_ocsp_response(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_pkcs12(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_pkey(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_pubkey(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_rand(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_ssl(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_ssl_context(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_altname(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_cert(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_chain(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_crl(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_csr(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_extension(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_name(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_store(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_store_context(state: ?*c.lua_State) c_int;
extern fn luaopen__openssl_x509_verify_param(state: ?*c.lua_State) c_int;

pub const Lua = struct {
    const Self = @This();
    state: ?*c.lua_State,

    pub fn new(state: *anyopaque) Self {
        const lua_state: *c.lua_State = @ptrCast(state);
        return Self{ .state = lua_state };
    }

    pub fn addToPath(
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

    pub fn preloadLib(
        self: *const Self,
        name: [*c]const u8,
        func: c.lua_CFunction,
    ) void {
        c.luaL_requiref(self.state, name, func, 1);
        c.lua_pop(self.state, 1);
    }

    pub fn preloadAll(self: *const Self) !void {
        self.preloadLib("lpeg", luaopen_lpeg);

        self.preloadLib("_cqueues", luaopen__cqueues);
        self.preloadLib("_cqueues.errno", luaopen__cqueues_errno);
        // self.preloadLib("_cqueues.thread", luaopen__cqueues_thread);
        // ^^ PANIC: unprotected error in call to Lua API (/home/ryan/dev/lua-http/zig-out/bin/lua_http_test: cannot dynamically load executable)
        self.preloadLib("_cqueues.dns", luaopen__cqueues_dns);
        self.preloadLib("_cqueues.socket", luaopen__cqueues_socket);
        self.preloadLib("_cqueues.signal", luaopen__cqueues_signal);
        self.preloadLib("_cqueues.notify", luaopen__cqueues_notify);
        self.preloadLib("_cqueues.condition", luaopen__cqueues_condition);
        self.preloadLib("_cqueues.debug", luaopen__cqueues_debug);

        self.preloadLib("_openssl", luaopen__openssl);
        // self.preloadLib("_openssl.x509.name", luaopen__openssl_x509_name);
        // self.preloadLib("_openssl.x509.altname", luaopen__openssl_x509_altname);
        // self.preloadLib("_openssl.x509.extension", luaopen__openssl_x509_extension);
        // self.preloadLib("_openssl.x509.cert", luaopen__openssl_x509_cert);
        // self.preloadLib("_openssl.x509.csr", luaopen__openssl_x509_csr);
        // self.preloadLib("_openssl.x509.crl", luaopen__openssl_x509_crl);
        // self.preloadLib("_openssl.x509.chain", luaopen__openssl_x509_chain);
        // self.preloadLib("_openssl.x509.store", luaopen__openssl_x509_store);
        // // self.preloadLib("_openssl.x509.store.context", luaopen__openssl_x509_store_context);
        // // ^^ error: undefined symbol: luaopen__openssl_x509_store_context
        // self.preloadLib("_openssl.x509.verify.param", luaopen__openssl_x509_verify_param);

        self.preloadLib("_openssl.bignum", luaopen__openssl_bignum);
        self.preloadLib("_openssl.cipher", luaopen__openssl_cipher);
        self.preloadLib("_openssl.compat", luaopen__openssl_compat);
        self.preloadLib("_openssl.des", luaopen__openssl_des);
        self.preloadLib("_openssl.digest", luaopen__openssl_digest);
        self.preloadLib("_openssl.ec.group", luaopen__openssl_ec_group);
        self.preloadLib("_openssl.hmac", luaopen__openssl_hmac);
        self.preloadLib("_openssl.kdf", luaopen__openssl_kdf);
        self.preloadLib("_openssl.ocsp.basic", luaopen__openssl_ocsp_basic);
        self.preloadLib("_openssl.ocsp.response", luaopen__openssl_ocsp_response);
        self.preloadLib("_openssl.pkcs12", luaopen__openssl_pkcs12);
        self.preloadLib("_openssl.pkey", luaopen__openssl_pkey);
        self.preloadLib("_openssl.pubkey", luaopen__openssl_pubkey);
        self.preloadLib("_openssl.rand", luaopen__openssl_rand);
        self.preloadLib("_openssl.ssl", luaopen__openssl_ssl);
        self.preloadLib("_openssl.ssl.context", luaopen__openssl_ssl_context);
        self.preloadLib("_openssl.x509.altname", luaopen__openssl_x509_altname);
        self.preloadLib("_openssl.x509.cert", luaopen__openssl_x509_cert);
        self.preloadLib("_openssl.x509.chain", luaopen__openssl_x509_chain);
        self.preloadLib("_openssl.x509.crl", luaopen__openssl_x509_crl);
        self.preloadLib("_openssl.x509.csr", luaopen__openssl_x509_csr);
        self.preloadLib("_openssl.x509.extension", luaopen__openssl_x509_extension);
        self.preloadLib("_openssl.x509.name", luaopen__openssl_x509_name);
        self.preloadLib("_openssl.x509.store", luaopen__openssl_x509_store);
        // self.preloadLib("_openssl.x509.store.context", luaopen__openssl_x509_store_context);
        // ^^ error: undefined symbol: luaopen__openssl_x509_store_context
        self.preloadLib("_openssl.x509.verify.param", luaopen__openssl_x509_verify_param);
    }
};
