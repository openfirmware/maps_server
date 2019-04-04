# maps\_server CHANGELOG

This file is used to list changes made in each version of the maps\_server cookbook.

# 0.2.0

"ArcticWebMap" release.

* Install PostgreSQL from Postgres Apt Repository
* Add recipe for monitoring using Munin (accessible at `/munin/`)
* Add mod_tile, osmosis plugins for Munin
* Use attributes to allow `osm2pgsql` re-imports
* Allow merging of multiple `.pbf` files before import
* Set up fixed-size disks for vagrant when testing cookbook locally
* Add `basic_monitoring` recipe for installation before PostgreSQL
* Allow specification of more PostgreSQL settings in attributes files
* Use long timeouts on resources that are expected to take a long time to run
* Support alternate PostgreSQL data directory
* Re-use library and resource code from [openstreetmap/chef](https://github.com/openstreetmap/chef)
* Separate PostgreSQL attributes and stylesheet attributes to separate files
* Standardize on double-quotes over single-quotes in Ruby
* Move database setup and import into stylesheet recipes
* Use EPSG:3857 for openstreetmap-carto (the default projection) instead of EPSG:4326
* Set up `renderd` configuration using normal attribute merging
* Store tile configurations at `/tiles.json` for usage by web clients
* Add recipe for ArcticWebMap style 2.0
* Manually install `libspatialite` to include `liblwgeom` support for GDAL
* Fix timeouts for Postgres execute resource

# 0.1.0

Initial release.

* Install software for a database and tile server
* Import an OSM extract for Alberta, Canada to the database
* Set up stylesheet for openstreetmap-carto and mod\_tile
* Install sample clients with Leaflet and OpenLayers 4
