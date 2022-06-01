const std = @import("std");
const clap = @import("clap");
const zigdal = @import("zigdal.zig");
const ogr_srs = @import("ogr_srs.zig");
const zig_arg = @import("zig-arg");

const io = std.io;
const print = std.debug.print; 
const assert = std.debug.assert;
const fmt = std.fmt;

pub fn parseFloat(comptime T: type) fn ([]const u8) fmt.ParseFloatError!T {
    return struct {
        fn parse(in: []const u8) fmt.ParseFloatError!T {
            var tmp: [32]u8 = [_]u8{0} ** 32;
            std.mem.copy(u8, tmp[0..32], in);
            if(tmp[0] == '_') tmp[0] = '-';
            return fmt.parseFloat(T, tmp[0.. in.len]);
        }
    }.parse;
}

const parsers = .{
    .STR = clap.parsers.string,
    .FILE = clap.parsers.string,
    .INT = clap.parsers.int(usize, 10),
    .FLOAT = parseFloat(f64),
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
            print("Setting Nodata: {d}\n", .{nodataVal});
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

pub fn main2() anyerror!void {
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

pub fn main() anyerror!void {
    // Arena allocator is recommended for cmd-line apps such as this one, where
    // memory can be freed at the end, all at once, according to docs...
    zigdal.init();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const argv = try std.process.argsAlloc(allocator);

    var app = zig_arg.Command.new(allocator, "app");
    try app.addArg(zig_arg.flag.boolean("help", 'h'));
    defer app.deinit();

    var edit = zig_arg.Command.new(allocator, "edit");
    try edit.addArg(zig_arg.flag.boolean("help", 'h'));
    try edit.addArg(zig_arg.flag.argOne("nodata", null));
    try edit.addArg(zig_arg.flag.argOne("refsys", 'r'));
    try edit.addArg(zig_arg.flag.argOne("output", 'o'));
    try app.addSubcommand(edit);

    var app_args = app.parse(argv[1..]) catch {
            print("SYNTAX ERROR: {s}\n", .{argv[0]});
            syntaxMsg();
            std.os.exit(1);
    };

    defer app_args.deinit();
    if(app_args.isPresent("help")) {
        syntaxMsg();
        std.os.exit(0);
    }

    if(app_args.subcommandMatches("edit")) |edit_args| {

        print("Edit", .{});
        if(edit_args.isPresent("help")) {
            print("Edit HELP", .{});
            std.os.exit(0);
        }


        if(edit_args.valueOf("refsys")) |refsys| {
            var epsg = try fmt.parseInt(c_int, refsys, 10); 
            // catch {
            //    print("refsys arg should be an integer (EPSG code)", .{ refsys });
            //};

            if(edit_args.valueOf("output")) |fname| {
                const rs = try ogr_srs.newSpatialReferenceFromEPSG(epsg);
                const ds = try zigdal.open(fname, zigdal.Access.Update);

                try zigdal.setSpatialRef(ds, rs);


            }
        }

        std.os.exit(0);
    }



}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
    _ = @import("zigdal.zig");
    _ = @import("ogr_srs.zig");
}
