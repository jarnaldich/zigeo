# zigeo
Geospatial command-line tools in Zig

This is a first experiment on wrapping some geospatial libraries in Zig. 

Still very rough. May be useful in the future to access some utilites that are not easily available in other command-line tools (GDAL/ogr, etc...).

To fetch the `clap` dependency,  [zigmod](https://github.com/nektro/zigmod) is needed. Just download a release an execute `zigmod fetch` from the project dir.

**WARNING**: As many zig projects, it is a moving target: the language itself or any dependency may change in breaking ways, so expect problems compiling after a while.

# references for mis. tasks  in no particular order

- https://stackoverflow.com/questions/66527365/how-to-concat-two-string-literals-at-compile-time-in-zig
