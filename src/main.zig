const std = @import("std");
const clap = @import("clap");
const zigdal = @import("zigdal.zig");

const io = std.io;
const print = std.debug.print; 
const assert = std.debug.assert;
const parsers = .{
    .STR = clap.parsers.string,
    .FILE = clap.parsers.string,
    .INT = clap.parsers.int(usize, 10),
    .FLOAT = clap.parsers.float(f64),
};


pub fn syntaxMsg() void {
    print(
        \\
        \\zigeo - Utilities for geospatial data processing
        \\
        \\Syntax: zigeo [-h|--help] <command>
        \\
        \\Options:
        \\  -h, --help: print this help and exit.
        \\
        \\Commands:
        \\  edit - in-place editing of information (think gdal_edit.py)
        \\
        \\Further information on subcommands can be found by executing:
        \\  zigeo <command> [-h|--help]
        \\
    , .{});
}

const Command = enum {
    edit
};

// ----------------------------------- EDIT ----------------------------------------
const edit_params = [_]clap.Param(clap.Help){
    clap.parseParam("-h, --help             Display this help and exit.              ") catch unreachable,
    clap.parseParam("-n, --nodata <FLOAT>     An option parameter, which takes a value.") catch unreachable,
    clap.parseParam("<FILE>...") catch unreachable,
};
 
pub fn do_edit(allocator: std.mem.Allocator, iter: *std.process.ArgIterator) !void {
    var diag = clap.Diagnostic{};
    var args = clap.parseEx(clap.Help, &edit_params, parsers, iter,  .{ .diagnostic = &diag, .allocator = allocator }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };

    if (args.args.nodata) |nodataStr| {
        for (args.positionals) |pos| {
            const ds = try zigdal.open(pos, zigdal.Access.Update);
            defer zigdal.close(ds);

            const nodataVal = nodataStr; // try std.fmt.parseFloat(f64, nodataStr);
            const numBands = zigdal.getRasterCount(ds);
            var iBand : u32 = 1;
            while(iBand <= numBands) : (iBand += 1) {
                const band = try zigdal.getRasterBand(ds, iBand);
                try zigdal.setRasterNoDataValue(band, nodataVal); 
            }
            
            _ = nodataVal;
            print("{s}\n", .{pos});
            print("{s}\n", .{ds});
        }
    } 
}

pub fn main() anyerror!void {
    // Arena allocator is recommended for cmd-line apps such as this one, where
    // memory can be freed at the end, all at once, according to docs...
    zigdal.init();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();
    print("{s}\n", .{@typeName(@TypeOf(iter))});
 
    // Skip exe arg
    _ = iter.next();

    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-h, --help             Display this help and exit.              ") catch unreachable,
        clap.parseParam("-n, --nodata             Display this help and exit.              ") catch unreachable,
//        clap.parseParam("-n, --number <INT>     An option parameter, which takes a value.") catch unreachable,
//        clap.parseParam("-s, --string <STR>...  An option parameter which can be specified multiple times.") catch unreachable,
        clap.parseParam("<FILE>...") catch unreachable,
    };
    _ = params;

    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, parsers, .{ .diagnostic = &diag }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer args.deinit();

    if (args.args.help) {
        syntaxMsg();
        std.os.exit(0);
    }

//    if (args.option("--number")) |n| print("--number = {s}\n", .{n});
//    for (args.options("--string")) |s| print("--string = {s}\n", .{s});
//    for (args.positionals()) |pos| print("{s}\n", .{pos});

    if (args.positionals.len < 1) {
        syntaxMsg();
        std.os.exit(1);
    }
    //var arg_iter = try clap.args.OsIterator.init(allocator);
    var arg_iter = try std.process.ArgIterator.initWithAllocator(allocator);
 
    const cmdString = args.positionals[0];
    brk: while(arg_iter.next()) |param| {
        print("{s}\n", .{param});
//        if(param) |val| {
            if(std.mem.eql(u8, param, cmdString)) {
                print("Found {s}\n", .{param});
                break :brk;
            }
        //}
        //else |_| {
            //unreachable; 
        //}
    }  
    const cmd = std.meta.stringToEnum(Command, cmdString) orelse {
        print("Unknown command: {s}\n", .{ cmdString });
        std.os.exit(1);
    };

    switch(cmd) {
        .edit => try do_edit(allocator, &arg_iter),
    }



//    print("{s}\n", .{ command });
//    if (args.positionals()[0]) |pos| print("{s}\n", .{pos});
    // 
 

}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
    _ = @import("zigdal.zig");
}
