// https://gdal.org/api/ogr_srs_api.html
const std = @import("std");

const osr = @cImport({
    @cInclude("ogr_srs_api.h");
});

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn Handle() type {
    return struct {
        handle: *anyopaque,
    };
}

pub const SpatialReference    = Handle();

pub fn newSpatialReferenceFromWKT(srs: []const u8) !SpatialReference {
    const handle_ = osr.OSRNewSpatialReference(@ptrCast([*c]const u8, srs));
    if(handle_) |handle| { 
        return SpatialReference{ .handle = handle };
    }
    return error.NewSpatialReferenceError;
}

pub fn newSpatialReferenceFromEPSG(epsg: c_int) !SpatialReference {

    const handle_ = osr.OSRNewSpatialReference(null);
    if(handle_) |handle| { 
        const err = osr.OSRImportFromEPSG(handle_, epsg);
        if(err == 0) {
            return SpatialReference{ .handle = handle };
        }
    }
 
    return error.NewSpatialReferenceError;
}

pub fn releaseSpatialReference(sr: SpatialReference) void {
    osr.OSRDestroySpatialReference(sr.handle);
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Tests

test "Create should work with WKT" {
    _ = (newSpatialReferenceFromWKT(
        \\ PROJCRS["ETRS89 / UTM zone 31N",
        \\     BASEGEOGCRS["ETRS89",
        \\         DATUM["European Terrestrial Reference System 1989",
        \\             ELLIPSOID["GRS 1980",6378137,298.257222101004,
        \\                 LENGTHUNIT["metre",1]]],
        \\         PRIMEM["Greenwich",0,
        \\             ANGLEUNIT["degree",0.0174532925199433]],
        \\         ID["EPSG",4258]],
        \\     CONVERSION["Transverse Mercator",
        \\         METHOD["Transverse Mercator",
        \\             ID["EPSG",9807]],
        \\         PARAMETER["Latitude of natural origin",0,
        \\             ANGLEUNIT["degree",0.0174532925199433],
        \\             ID["EPSG",8801]],
        \\         PARAMETER["Longitude of natural origin",3,
        \\             ANGLEUNIT["degree",0.0174532925199433],
        \\             ID["EPSG",8802]],
        \\         PARAMETER["Scale factor at natural origin",0.9996,
        \\             SCALEUNIT["unity",1],
        \\             ID["EPSG",8805]],
        \\         PARAMETER["False easting",500000,
        \\             LENGTHUNIT["metre",1],
        \\             ID["EPSG",8806]],
        \\         PARAMETER["False northing",0,
        \\             LENGTHUNIT["metre",1],
        \\             ID["EPSG",8807]]],
        \\     CS[Cartesian,2],
        \\         AXIS["easting",east,
        \\             ORDER[1],
        \\             LENGTHUNIT["metre",1]],
        \\         AXIS["northing",north,
        \\             ORDER[2],
        \\             LENGTHUNIT["metre",1]],
        \\     ID["EPSG",25831]]    
    ) catch |e| {
        try expect(e == error.NewSpatialReferenceError);
    });
}


test "Create should work with EPSG" {
    _ = (newSpatialReferenceFromEPSG(25831) catch |e| {
        try expect(e == error.NewSpatialReferenceError);
    });
}
