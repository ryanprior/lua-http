const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lua_dep = b.dependency("lua", .{
        .target = target,
        .release = optimize != .Debug,
    });
    const lua_lib = lua_dep.artifact(if (target.result.os.tag == .windows)
        "lua54"
    else
        "lua");

    const luaossl_dep = b.dependency("luaossl", .{
        .target = target,
        .optimize = optimize,
    });
    const luaossl_lib = luaossl_dep.artifact("luaossl");

    const cqueues_dep = b.dependency("cqueues", .{
        .target = target,
        .optimize = optimize,
    });
    const cqueues_lib = cqueues_dep.artifact("cqueues");

    const lpeg_dep = b.dependency("lpeg", .{});
    const fifo_dep = b.dependency("lua_fifo", .{});
    const basexx_dep = b.dependency("lua_basexx", .{});
    const lpeg_patterns_dep = b.dependency("lua_lpeg_patterns", .{});
    const binary_heap_dep = b.dependency("lua_binary_heap", .{});

    const lpeg_lib = b.addLibrary(.{
        .name = "lpeg",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    lpeg_lib.root_module.linkLibrary(lua_lib);

    const lua_http_module = b.addModule("lua-http", .{
        .root_source_file = b.path("init.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lua_http_lib = b.addLibrary(.{
        .name = "lua-http",
        .root_module = lua_http_module,
    });
    lua_http_lib.root_module.linkLibrary(lua_lib);
    lua_http_lib.root_module.linkLibrary(lpeg_lib);
    lua_http_lib.root_module.linkLibrary(luaossl_lib);
    lua_http_lib.root_module.linkLibrary(cqueues_lib);

    const exe = b.addExecutable(.{
        .name = "lua-http-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.linkLibrary(lua_lib);
    exe.root_module.linkLibrary(luaossl_lib);
    exe.root_module.linkLibrary(cqueues_lib);

    for (lpeg_source_files) |file| {
        lpeg_lib.root_module.addCSourceFile(
            .{ .file = lpeg_dep.path(file) },
        );
        exe.root_module.addCSourceFile(
            .{ .file = lpeg_dep.path(file) },
        );
    }
    exe.root_module.addIncludePath(lpeg_dep.path(""));
    exe.root_module.addIncludePath(lua_dep.artifact("lua").getEmittedIncludeTree());

    b.installArtifact(exe);
    b.installArtifact(lua_http_lib);
    b.installArtifact(lpeg_lib);

    const install_fifo = b.addInstallFileWithDir(
        fifo_dep.path("fifo.lua"),
        .prefix,
        "share/lua/5.4/fifo.lua",
    );
    const install_basexx = b.addInstallFileWithDir(
        basexx_dep.path("lib/basexx.lua"),
        .prefix,
        "share/lua/5.4/basexx.lua",
    );
    const install_lpeg_patterns = b.addInstallDirectory(.{
        .source_dir = lpeg_patterns_dep.path("lpeg_patterns"),
        .install_dir = .prefix,
        .install_subdir = "share/lua/5.4/lpeg_patterns",
    });
    const install_binary_heap = b.addInstallFileWithDir(
        binary_heap_dep.path("src/binaryheap.lua"),
        .prefix,
        "share/lua/5.4/binaryheap.lua",
    );
    const install_cqueues = b.addInstallDirectory(.{
        .source_dir = cqueues_dep.path("src"),
        .install_dir = .prefix,
        .install_subdir = "share/lua/5.4/cqueues",
        .include_extensions = &.{".lua"},
    });
    const install_cqueues_lua = b.addInstallFileWithDir(
        cqueues_dep.path("src/cqueues.lua"),
        .prefix,
        "share/lua/5.4/cqueues.lua",
    );
    const install_luaossl = b.addInstallDirectory(.{
        .source_dir = luaossl_dep.path("src/openssl"),
        .install_dir = .prefix,
        .install_subdir = "share/lua/5.4/openssl",
        .include_extensions = &.{".lua"},
    });
    const install_luaossl_lua = b.addInstallFileWithDir(
        luaossl_dep.path("src/openssl.lua"),
        .prefix,
        "share/lua/5.4/openssl.lua",
    );
    const lua_path = b.pathJoin(&.{
        b.install_path,
        "share/lua/5.4/?.lua",
    });
    const options = b.addOptions();
    options.addOption([]const u8, "lua_path", lua_path);
    exe.root_module.addOptions("build_options", options);
    b.getInstallStep().dependOn(&install_fifo.step);
    b.getInstallStep().dependOn(&install_basexx.step);
    b.getInstallStep().dependOn(&install_lpeg_patterns.step);
    b.getInstallStep().dependOn(&install_binary_heap.step);
    b.getInstallStep().dependOn(&install_cqueues.step);
    b.getInstallStep().dependOn(&install_cqueues_lua.step);
    b.getInstallStep().dependOn(&install_luaossl.step);
    b.getInstallStep().dependOn(&install_luaossl_lua.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // const mod_tests = b.addTest(.{
    //     .root_module = mod,
    // });

    // A run step that will run the test executable.
    // const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    // const exe_tests = b.addTest(.{
    //     .root_module = exe.root_module,
    // });

    // A run step that will run the second test executable.
    // const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);
}

const lpeg_source_files = [_][]const u8{
    "lpcap.c",
    "lpcode.c",
    "lpcset.c",
    "lpprint.c",
    "lptree.c",
    "lpvm.c",
};
