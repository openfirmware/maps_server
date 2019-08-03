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

## Attributes

All of the attributes in `attributes/default.rb` have been documented with default values and what they are used for in the recipes.

## Recipes

### `default` Recipe

Including the default recipe, `maps_server` or `maps_server::default`, will set up the database and web server. It does not set up Apache/mod\_tile nor download and import an extract to PostgreSQL, see the `openstreetmap_carto` recipe for that.

* Install [PostgreSQL][] 11
* Install [GDAL][]
* Install [PostGIS][] 2.5.0
* Install [osm2pgsql][]
* Install [Apache HTTP Server][] 2.4
* Install [mapnik][]
* Install [mod\_tile][modtile]

[Apache HTTP Server]: https://httpd.apache.org
[GDAL]: https://www.gdal.org
[mapnik]: https://mapnik.org
[modtile]: https://github.com/openstreetmap/mod_tile
[osm2pgsql]: https://github.com/openstreetmap/osm2pgsql
[PostGIS]: http://postgis.net
[PostgreSQL]: https://www.postgresql.org

### `arcticwebmap` Recipe

Installs the [awm-styles][] stylesheet, downloads extracts, sets up the database and database user, imports the data to PostgreSQL in EPSG:3573 projection, then sets up renderd and Apache. Also installs Leaflet/OpenLayers demo sites to `/leaflet.html` and `/openlayers.html`.

* Download [extract of OpenStreetMap data][GeoFabrik]
* Download [awm-styles][] for import scripts
* Optimize PostgreSQL for imports
* Crop extract to smaller region (optional)
* Import OpenStreetMap data to PostgreSQL
* Optimize PostgreSQL for tile serving
* Download shapefiles and rasters
* Install fonts for the stylesheet
* Set up additional PostgreSQL indexes for the stylesheet
* Set up raster tile rendering for the stylesheet
* Deploy a static website with [Leaflet][] for browsing the raster tiles
* Deploy a static website with [OpenLayers][] for browsing the raster tiles

This recipe can be ran with or without the `openstreetmap-carto` recipe, they should co-exist as long as they have different data storage paths defined in their attributes.

[awm-styles]: https://github.com/GeoSensorWebLab/awm-styles
[GeoFabrik]: http://download.geofabrik.de
[Leaflet]: https://leafletjs.com
[OpenLayers]: http://openlayers.org
[openstreetmap-carto]: https://github.com/gravitystorm/openstreetmap-carto

### `base_monitoring` Recipe

Installs the munin/rrdtool/Apache 2 monitoring stack. This recipe is meant to be runnable *before* the `default` recipe, so that you can collect statistics during the import.

For PostgreSQL and `mod_tile` monitoring plugins, use the `monitoring` recipe.

### `mapproxy` Recipe

Installs MapProxy for serving Mapnik stylesheets via WMS, WMS-C, and/or WMTS. Must be ran *after* setting up PostgreSQL and Mapnik using `openstreetmap_carto` or `arcticwebmap`, as this recipe depends on the import and stylesheets already existing.

The recipe will install Apache2 if it hasn't already been installed, and set up the WSCGI module for serving the MapProxy python application at the HTTP path `/mapproxy`.

Configuration of services, layers, caches, sources, and grids are all handled in `attributes/mapproxy.rb`. A complete example is included in that attributes file.

A demo site using OpenLayers for previewing the WMS/WMTS is enabled at `/mapproxy/demo`. The demo can be disabled in the MapProxy configuration.

MapProxy tiles should be generated in one or more caches in `/srv/tiles/mapproxy`, and Apache is set to serve that directory for public download of tile caches. Gzip compression is enabled for download of GeoPackages as it has a significant effect on the file size.

For seeding tiles, the following command is recommended to be ran manually:

```
$ sudo -u www-data mapproxy-seed --seed-conf=/opt/mapproxy/seed.yaml \
  --proxy-conf=/opt/mapproxy/mapproxy.yaml \
  --concurrency 6 -i
```

Adjust the concurrency for your instance.

### `monitoring` Recipe

Runs the `base_monitoring` recipe, then installs custom Munin plugins to collect statistics from PostgreSQL and `mod_tile`.

### `openstreetmap_carto` Recipe

Installs the openstreetmap-carto stylesheet, downloads extracts, sets up the database and database user, imports the data to PostgreSQL, then sets up renderd and Apache. Also installs Leaflet/OpenLayers demo sites to `/leaflet.html` and `/openlayers.html`.

Download/setup/import of the database has been moved to this recipe as different stylesheets may require different import options (projection, regions, etc).

* Download [extract of OpenStreetMap data][GeoFabrik]
* Download [openstreetmap-carto][] for import scripts
* Optimize PostgreSQL for imports
* Crop extract to smaller region (optional)
* Import OpenStreetMap data to PostgreSQL
* Optimize PostgreSQL for tile serving
* Download [CartoCSS stylesheets][openstreetmap-carto]
* Download shapefiles
* Install fonts for the stylesheet
* Set up additional PostgreSQL indexes for the stylesheet
* Set up raster tile rendering for the stylesheet
* Deploy a static website with [Leaflet][] for browsing the raster tiles
* Deploy a static website with [OpenLayers][] for browsing the raster tiles

This recipe can be ran with or without the `arcticwebmap` recipe, they should co-exist as long as they have different data storage paths defined in their attributes.

[GeoFabrik]: http://download.geofabrik.de
[Leaflet]: https://leafletjs.com
[OpenLayers]: http://openlayers.org
[openstreetmap-carto]: https://github.com/gravitystorm/openstreetmap-carto

## WIP Recipes

### `canvec` Recipe

TODO: Will add an additional recipe for setting up a second database with data from Natural Resources Canada ([PDF](https://www.nrcan.gc.ca/sites/www.nrcan.gc.ca/files/earthsciences/pdf/CanVec_en.pdf))

* Download CanVec data
* Import into PostgreSQL using GDAL
* Add indexes for the stylesheet

### `tilestrata` Recipe

TODO: Try using [TileStrata][] as an alternative to mod\_tile for generating raster and vector tiles.

[TileStrata]: https://github.com/naturalatlas/tilestrata

## Test Kitchen Optimizations

Test Kitchen is a tool for setting up a local virtual machine that you can deploy this cookbook for testing. TK supports multiple "drivers", but the main ones are Vagrant with VirtualBox. Here are a few optimizations that should be used in `.kitchen.yml` depending on your development hardware/OS.

**Important Note**: The VM will require 70 GB of free space on the host machine, due to the use of fixed allocation disks (see below for why).

#### Customize VM Options

Adjust these based on your available hardware. These values are based on [VirtualBox][VirtualBox Config].

```yaml
driver:
  name: vagrant
  customize:
    cpus: 4
    memory: 8192
    storagectl:
      - name: "SATA Controller"
        hostiocache: "off"
```

Disabling the Host I/O cache in VirtualBox noticeably increases disk sequential and random read/write speeds.

[VirtualBox Config]: https://www.vagrantup.com/docs/virtualbox/configuration.html

#### Set a Synced Cache Directory

Stores extracts and shapefiles on the HOST machine so they don't have to be re-downloaded. First example below is for MacOS, second is for Linux.

```yaml
driver:
  synced_folders:
    - ["/Users/YOU/Library/Caches/vagrant/%{instance_name}", "/srv/data", "create: true, type: :rsync"]
    - ["/home/YOU/data/vagrant/%{instance_name}", "/srv/data", "create: true, type: :rsync"]
```

These use the [RSync synced folders][RSync Synced Folders] instead of VirtualBox/NFS/SMB as the latter have a performance penalty which will slow down imports of PBF extracts. As the RSync method has to copy the files into the VM, it will be a bit slower to create the VM using `kitchen create`.

To sync updated shared folders back to the cache directory on the host, use the [vagrant-rsync-back][] plugin. Note that syncing to and from the VM uses the rsync `--delete` argument, so the destination will be cleaned to match the source.

[RSync Synced Folders]: https://www.vagrantup.com/docs/synced-folders/rsync.html
[vagrant-rsync-back]:https://github.com/smerrill/vagrant-rsync-back

#### Use Fixed VirtualBox Disk Images

I have included a custom Vagrantfile (`Vagrant_fixed_disks.rb`) that will use the [Vagrant Disksize plugin][] to resize the base box image to 64 GB **and** use fixed allocation, courtesy of a monkey patch.

Fixed allocation disks offer a 2-3 times improvement in sequential write speeds, which is pretty important for a database driven cookbook like this one.

[Vagrant Disksize plugin]: https://github.com/sprotheroe/vagrant-disksize

## License

Apache 2.0

