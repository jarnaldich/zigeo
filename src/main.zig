const std = @import("std");
const clap = @import("clap");

const io = std.io;
const print = std.debug.print; 

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});

    const allocator = std.heap.page_allocator;

    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    // Skip exe arg
    _ = iter.next(allocator);
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-h, --help             Display this help and exit.              ") catch unreachable,
//        clap.parseParam("-n, --number <INT>     An option parameter, which takes a value.") catch unreachable,
//        clap.parseParam("-s, --string <STR>...  An option parameter which can be specified multiple times.") catch unreachable,
        clap.parseParam("<POS>") catch unreachable,
    };
    _ = params;

    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer args.deinit();
    print("{s}\n", .{@typeName(@TypeOf(args.positionals()))});

    if (args.flag("--help"))
        print("--help\n", .{});

//    if (args.option("--number")) |n| print("--number = {s}\n", .{n});
//    for (args.options("--string")) |s| print("--string = {s}\n", .{s});
    for (args.positionals()) |pos|
        print("{s}\n", .{pos});

    if (args.positionals().len < 1) {
        print("Syntax...", .{});
        std.os.exit(1);
    }

//    print("{s}\n", .{ command });
//    if (args.positionals()[0]) |pos| print("{s}\n", .{pos});
    // 
 

}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
