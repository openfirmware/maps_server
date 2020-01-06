# maps\_server CHANGELOG

This file is used to list changes made in each version of the maps\_server cookbook.

# 1.0.0

Stable release.

* Fix issue with MapProxy not being accessible using Apache when using `mod_tile` Tile Server
* Switch to only a single tile cache for MapProxy, as it does not support multiple caches with WMTS
* Update Munin plugin for planet age to monitor each database/stylesheet separately
* Upgrade to use Ruby 2.7.0 for cookbook
* Unlock Chef gem to allow use of 15 and newer
* Switch Munin planet age plugin to use days instead of years, as fractions of years are less readable than integer days

# 0.3.0

"MapProxy" release.

* Fix for reading wrong attribute level
* Auto-accept Chef license when setting up Test Kitchen VMs
* Update OSM shapefile download URLs to new host
* Fix for NPM using wrong system user
* Fix failure where renderd is restarted too quickly
* Add recipe for installing MapProxy
* Automatically configure Apache to serve MapProxy
* Add `www-data` as a database user for MapProxy usage
* Build tile caches to GeoPackages for easier re-use
* Provide some sample MapProxy seed configuration
* Enable gzip compression for downloading tile cache GeoPackages

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

# Road Map

* Switch to PostgreSQL 12
* Switch to PostGIS 3.0

These upgrades are probably safe on a fresh node with no existing database, but I am not sure about an in-place upgrade from PostgreSQL 11/PostGIS 2.5.
