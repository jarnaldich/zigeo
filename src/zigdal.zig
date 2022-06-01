const std = @import("std");
const gdal = @cImport({
    @cInclude("gdal.h");
});
const ogr_srs = @import("ogr_srs.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn init() void {
    gdal.GDALAllRegister();
}

pub const Info = enum(u8) {
    VERSION_NUM,
    RELEASE_DATE,
    RELEASE_NAME,
    pub fn toString(self: Info) [:0]const u8 {
        return switch(self) {
            Info.VERSION_NUM => "VERSION_NUM",
            Info.RELEASE_DATE => "RELEASE_DATE",
            Info.RELEASE_NAME => "RELEASE_NAME",
        };
    }
};

pub const DataType = enum(u32) {
    Unknown = gdal.GDT_Unknown,
    Byte = gdal.GDT_Byte,
    UInt16 = gdal.GDT_UInt16,
    Int16 = gdal.GDT_Int16,
    UInt32 = gdal.GDT_UInt32,
    Int32 = gdal.GDT_Int32,
//    UInt64 = gdal.GDT_UInt64,
//    Int64 = gdal.GDT_Int64,
    Float32 = gdal.GDT_Float32,
    Float64 = gdal.GDT_Float64,
    CInt16 = gdal.GDT_CInt16,
    CInt32 = gdal.GDT_CInt32,
    CFloat32 = gdal.GDT_CFloat32,
    CFloat64 = gdal.GDT_CFloat64,
    TypeCount = gdal.GDT_TypeCount,

    pub fn name(self: DataType) []const u8 {
        return std.mem.span(gdal.GDALGetDataTypeName(@enumToInt(self)));
    }
};

pub const Access = enum(c_uint) {
    ReadOnly = gdal.GA_ReadOnly,
    Update = gdal.GA_Update,
};

pub const CPLError = error {
    Debug,
    Warning,
    Failure,
    Fatal,
};

fn Handle() type {
    return struct {
        handle: *anyopaque,
    };
}

pub const Band    = Handle();
pub const DataSet = Handle();
pub const Driver  = Handle();


pub fn open(fname: []const u8, access: Access) !DataSet {
    var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    std.mem.copy(u8, buffer[0..fname.len], fname);
    buffer[fname.len] = 0;

    const handle_ = gdal.GDALOpen(@ptrCast([*c]const u8, fname), @enumToInt(access));
    if (handle_) |handle| {
        return DataSet{ .handle = handle };
    }
    return error.OpenError;
}

pub fn setSpatialRef(ds: DataSet, sr: ogr_srs.SpatialReference) !void {
    return toError(gdal.GDALSetSpatialRef(ds.handle, sr.handle));
}

pub fn close(ds: DataSet) void {
    gdal.GDALClose(ds.handle);
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

pub fn versionInfo(info: Info) []const u8 {
    return std.mem.span(gdal.GDALVersionInfo(info.toString()));
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

pub fn getProjectionRef(ds: DataSet) []const u8 {
    return std.mem.span(gdal.GDALGetProjectionRef(ds.handle));
}

pub fn toError(err: c_uint) CPLError!void {
   switch(err) {
       gdal.CE_Fatal   => return CPLError.Fatal,
       gdal.CE_Debug   => return CPLError.Debug,
       gdal.CE_Warning => return CPLError.Warning,
       gdal.CE_Failure => return CPLError.Failure,
       else => return,
   }
}

pub fn getGeoTransform(ds: DataSet, gt: *[6]f64) CPLError!void {
   switch(gdal.GDALGetGeoTransform(ds.handle, gt)) {
       gdal.CE_Fatal   => return CPLError.Fatal,
       gdal.CE_Debug   => return CPLError.Debug,
       gdal.CE_Warning => return CPLError.Warning,
       gdal.CE_Failure => return CPLError.Failure,
       else => return,
   }
}

pub fn getRasterBand(ds: DataSet, index: u32) !Band {
    const band_ = gdal.GDALGetRasterBand(ds.handle, @intCast(c_int, index));
    if(band_) |band| {
        return Band{ .handle = band };
    }
    return error.NoBand;
}

pub fn getRasterDataType(b: Band) DataType {
    return @intToEnum(DataType, gdal.GDALGetRasterDataType(b.handle));
}

pub fn setRasterNoDataValue(b: Band, nodata: f64) CPLError!void {
    return toError(gdal.GDALSetRasterNoDataValue(b.handle, nodata));
}


pub fn deleteRasterNoDataValue(b: Band) CPLError!void {
    return toError(gdal.GDALDeleteRasterNoDataValue(b.handle));
}


pub fn getRasterNoDataValue(b: Band) !f64 {
    var i : c_int = 0;
    const nodata : f64 = gdal.GDALGetRasterNoDataValue(b.handle, &i);
    if(i > 0) {
        return nodata;
    } else {
        return error.EmptyNodata;
    }
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

    const ds = try open(buf[0..len], Access.Update);
    defer close(ds);

    try expect(getRasterXSize(ds) == 2);
    try expect(getRasterYSize(ds) == 3);
    try expect(getRasterCount(ds) == 1);

    const driver = try getDriver(ds);
    const shortName = getDriverShortName(driver);
    const longName = getDriverLongName(driver);
    const projectionRef = getProjectionRef(ds);

    try expectEqual(true, std.mem.eql(u8, shortName, "AAIGrid"));
    try expectEqual(true, std.mem.eql(u8, longName,  "Arc/Info ASCII Grid"));
    try expectEqual(true, std.mem.eql(u8, projectionRef,  ""));

    var geotransform = [6]f64{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    var checkTransform = [6]f64{ 0, 10, 0, 30, 0, -10};
    try getGeoTransform(ds, &geotransform);
    try expectEqual(geotransform, checkTransform);
    
    const band = try getRasterBand(ds, 1);
    const dtype = getRasterDataType(band);
    try expectEqual(DataType.Float32, dtype);
    try expect(std.mem.eql(u8, "Float32", dtype.name()));

    const versionNum = try std.fmt.parseInt(c_int, versionInfo(Info.VERSION_NUM), 0);
    try expectEqual(gdal.GDAL_VERSION_NUM, versionNum);

    const nodata = try getRasterNoDataValue(band);
    try expectEqual(@as(f64, -9999.0), nodata);

//    try setRasterNoDataValue(band, -8888.0);
//    try expectEqual(@as(f64, -8888.0), nodata);

    std.debug.print("\n{s}, {d}\n", .{versionInfo(Info.VERSION_NUM), getRasterNoDataValue(band)});
    std.debug.print("\nExe: {s}\n", .{@ptrCast([*c]const u8, &buf)});
}
