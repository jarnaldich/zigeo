const std = @import("std");
const gdal = @cImport({
    @cInclude("gdal.h");
});

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn init() void {
    gdal.GDALAllRegister();
}

pub const Access = enum(u32) {
    ReadOnly = gdal.GA_ReadOnly,
    pub fn toGdal(self: Access) c_uint {
        return switch (self) {
            .ReadOnly => gdal.GA_ReadOnly,
        };
    }
};

pub const DataSet = struct {
    handle: *anyopaque,
};

pub const Driver = struct {
    handle: *anyopaque,
};

pub fn open(fname: []const u8, access: Access) !DataSet {
    var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    std.mem.copy(u8, buffer[0..fname.len], fname);
    buffer[fname.len] = 0;

    const handle_ = gdal.GDALOpen(@ptrCast([*c]const u8, fname), access.toGdal());
    if (handle_) |handle| {
        return DataSet{ .handle = handle };
    }
    return error.OpenError;
}

pub fn getRasterXSize(ds: DataSet) u32 {
    return @intCast(u32, gdal.GDALGetRasterXSize(ds.handle));
}
pub fn getRasterYSize(ds: DataSet) u32 {
    return @intCast(u32, gdal.GDALGetRasterYSize(ds.handle));
}

pub fn getRasterCount(ds: DataSet) u32 {
    return @intCast(u32, gdal.GDALGetRasterCount(ds.handle));
}

pub fn getDriver(ds: DataSet) !Driver {
    const driver_ =  gdal.GDALGetDatasetDriver(ds.handle);
    if(driver_) |driver| {
        return Driver{ .handle = driver };
    }
    return error.GettingDriver;
}

pub fn getDriverShortName(driver: Driver) []const u8 {
    return std.mem.span(gdal.GDALGetDriverShortName(driver.handle));
}

pub fn getDriverLongName(driver: Driver) []const u8 {
    return std.mem.span(gdal.GDALGetDriverLongName(driver.handle));
}

test "Open should fail if not exists" {
    _ = (open("patata", Access.ReadOnly) catch |e| {
        try expect(e == error.OpenError);
    });
}

test "Open should return correct path" {
    init();
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const relname = "/etc/test_data/sample.txt";
    const cwd = try std.os.getcwd(&buf);
    const len = cwd.len + relname.len;
    std.mem.copy(u8, buf[cwd.len..len], relname);
    buf[len] = 0;

    const ds = try open(buf[0..len], Access.ReadOnly);

    try expect(getRasterXSize(ds) == 2);
    try expect(getRasterYSize(ds) == 3);
    try expect(getRasterCount(ds) == 1);

    const driver = try getDriver(ds);
    const shortName = getDriverShortName(driver);
    const longName = getDriverLongName(driver);

    try expectEqual(true, std.mem.eql(u8, shortName, "AAIGrid"));
    try expectEqual(true, std.mem.eql(u8, longName,  "Arc/Info ASCII Grid"));

    std.debug.print("\n{s}\n", .{ longName });
    std.debug.print("\nExe: {s}\n", .{@ptrCast([*c]const u8, &buf)});
}
