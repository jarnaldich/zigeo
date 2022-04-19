const std = @import("std");
const deps = @import("./deps.zig");


pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    const dll = b.option(bool, "dll", "Use external dll (link against gdal_i)") orelse false;

    const gdal_home = std.process.getEnvVarOwned(b.allocator, "GDAL_HOME") catch "";
    defer b.allocator.free(gdal_home);

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zigeo", "src/main.zig");
    exe.setTarget(target);
    exe.linkLibC();
    if(gdal_home.len > 0)   {
        var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const includedir = std.fmt.bufPrint(&buffer, "{s}include\\", .{ gdal_home }) catch unreachable;
        exe.addIncludeDir(includedir);
        const libdir = std.fmt.bufPrint(&buffer, "{s}lib\\", .{ gdal_home }) catch unreachable;
        exe.addLibPath(libdir);
    }

    if(dll) {
        exe.linkSystemLibraryName("gdal_i");
    } else {
        exe.linkSystemLibraryName("gdal");
    }
 
    exe.setBuildMode(mode);
    deps.addAllTo(exe);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.linkLibC();
    exe_tests.linkSystemLibraryName("gdal");
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
