# Maps Server

Sets up a server with the database, tiling, and rendering software needed to serve raster and vector map data to web clients.

The goal of this cookbook is to be able to set up a server for either a city-level extract, or for a country level extract. The attributes file will be used to specify what kind of extract to use, and whether to download a pre-made extract (from a provider such as [GeoFabrik][]), or to generate an extract from the [OpenStreetMap][] planet file.

The cookbook is based on the instructions from [Switch2OSM][], with some additional changes I have learned from building [Arctic Web Map][].

[Arctic Web Map]: https://webmap.arcticconnect.ca
[OpenStreetMap]: https://wiki.openstreetmap.org/wiki/Main_Page
[Switch2OSM]: https://switch2osm.org

## Platform Support

This cookbook is designed for Ubuntu Server 18.04 LTS. I only have experience setting up these kinds of services on Ubuntu Server, so I would prefer to start with that platform.

## Hardware Requirements

There are some RAM, CPU, and disk IO requirements that have a huge performance impact on the speed of the data import and how fast the server can generate new tiles.

### City Level

A small server with 1 GB of RAM, 1 CPU, and spinning disk IO should be sufficient. The area is small enough that you can pre-generate all the tiles in a reasonable amount of time.

### Province/State Level

Cities will generally have the highest density of source data, and having more cities will increase the complexity and how much work the database will have to do for selecting data for tiles.

TODO: How much more hardware is needed?

### Country Level

More data will require more RAM to cache for the database, and having SSDs will help the database retrieve disk data. If you do not have enough RAM for the entire dataset, fast disk IO will have a *massive* performance bonus over spinning disk IO.

TODO: How much more hardware is needed?

### Continent or World Import

Do not do this, especially if you have not set up a smaller server yet. To put it gently, you will be wasting your time. This will take literal *days* to import the dataset to PostgreSQL with moderate hardware; only with expensive hardware do you get good performance. Pre-generating all tiles is not an option, as most tiles will be empty ocean and the number of tiles grows exponentially. For reference, I recommend checking out what the [OpenStreetMap Foundation uses for their hardware][OSMF Servers], as they are operating at the largest dataset scale and have a very high number of daily users.

[OSMF Servers]: https://hardware.openstreetmap.org

## Default Recipe

Including the default recipe, `maps_server` or `maps_server::default`, will set up everything.

* Install [PostgreSQL][] 10.5
* Install [GDAL][]
* Install [PostGIS][] 2.5.0
* Install [osm2pgsql][]
* Install [Apache HTTP Server][] 2.4
* Install [mapnik][]
* Install [mod_tile][]
* Download [extract of OpenStreetMap data][GeoFabrik]
* Download [CartoCSS stylesheets][openstreetmap-carto]
* Download shapefiles
* Install fonts for the stylesheet
* Optimize PostgreSQL for imports
* Crop extract to smaller region (optional)
* Import OpenStreetMap data to PostgreSQL
* Set up additional PostgreSQL indexes for the stylesheet
* Optimize PostgreSQL for tile serving
* Set up raster tile rendering for the stylesheet
* Deploy a static website with [Leaflet][] for browsing the raster tiles
* Deploy a static website with [OpenLayers][] for browsing the raster tiles
* Set up automatic sync for diffs from OpenStreetMap?

Note: Stylesheet and mod_tile configuration may be moved to a separate recipe, so that multiple stylesheets with different projections can be supported.

[Apache HTTP Server]: https://httpd.apache.org
[GDAL]: https://www.gdal.org
[GeoFabrik]: http://download.geofabrik.de
[Leaflet]: https://leafletjs.com
[mapnik]: https://mapnik.org
[mod_tile]: https://github.com/openstreetmap/mod_tile
[OpenLayers]: http://openlayers.org
[openstreetmap-carto]: https://github.com/gravitystorm/openstreetmap-carto
[osm2pgsql]: https://github.com/openstreetmap/osm2pgsql
[PostGIS]: http://postgis.net
[PostgreSQL]: https://www.postgresql.org

## CanVec Recipe

TODO: Will add an additional recipe for setting up a second database with data from Natural Resources Canada ([PDF](https://www.nrcan.gc.ca/sites/www.nrcan.gc.ca/files/earthsciences/pdf/CanVec_en.pdf))

* Download CanVec data
* Import into PostgreSQL using GDAL
* Add indexes for the stylesheet

## TileStrata Recipe

TODO: Try using [TileStrata][] as an alternative to mod_tile for generating raster and vector tiles.

[TileStrata]: https://github.com/naturalatlas/tilestrata

## Monitoring Recipe

TODO: Set up some kind of monitoring for viewing hardware usage and tile activity. The OSMF uses [Munin][] for these.

[Munin]: http://munin-monitoring.org

## License

Apache 2.0
