#########################
## openstreetmap-carto ##
#########################

# Source repo and branch/tag/ref
default[:maps_server][:openstreetmap_carto][:git_ref] = "v4.25.0"
default[:maps_server][:openstreetmap_carto][:git_repo] = "https://github.com/gravitystorm/openstreetmap-carto"

# Postgres Database to be created and loaded with OSM data
default[:maps_server][:openstreetmap_carto][:database_name] = "osm"
# mod_tile path under which tiles will be served via Apache
default[:maps_server][:openstreetmap_carto][:http_path] = "/osm-carto/"
# Recommended bounds (in EPSG:4326) that is sent to map clients
default[:maps_server][:openstreetmap_carto][:bounds] = [-122, 45, -100, 62]

#########
## NodeJS
#########
# Use the "xz" version.
default[:maps_server][:openstreetmap_carto][:nodejs_binaries] = "https://nodejs.org/download/release/v12.16.1/node-v12.16.1-linux-x64.tar.xz"
default[:maps_server][:openstreetmap_carto][:nodejs_version] = "12.16.1"
default[:maps_server][:openstreetmap_carto][:nodejs_prefix] = "/opt/nodejs"

##################
## Extract Sources
##################
# If extract date is set and any existing extract is older, then
# A) a new extract will be downloaded
# B) the local OSM database will be reloaded
# C) The database will be re-vacuumed after import
# D) stylesheet-specific indexes will be created again
# Date should be ISO8601 with a timezone. Leave as nil or empty string
# to ignore.
# For extract URLs, use PBF files only.
default[:maps_server][:openstreetmap_carto][:extracts] = [{
  extract_date_requirement: "2020-04-07T00:00:00+00:00",
  extract_url:              "https://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf",
  extract_checksum_url:     "https://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf.md5"
}, {
  extract_date_requirement: "2020-04-07T00:00:00+00:00",
  extract_url:              "https://download.geofabrik.de/north-america/canada/saskatchewan-latest.osm.pbf",
  extract_checksum_url:     "https://download.geofabrik.de/north-america/canada/saskatchewan-latest.osm.pbf.md5"
}]
# Crop the extract to a given bounding box
# Use a blank array or nil for no crop
# Order is the same as used by osm2pgsql:
# min longitude, min latitude, max longitude,
# max latitude
default[:maps_server][:openstreetmap_carto][:crop_bounding_box] = []
# default[:osm2pgsql][:crop_bounding_box] = [-115, 50, -113, 52]

# Shapefiles for the stylesheet
# check: skip extract step if this file exists (relative to
#        installation directory)
# url: source of archive to download. Will not re-download file.
default[:maps_server][:openstreetmap_carto][:shapefiles] = [{
  check: "data/simplified-water-polygons-split-3857/simplified_water_polygons.shp",
  url: "https://osmdata.openstreetmap.de/download/simplified-water-polygons-split-3857.zip"
},{
  check: "data/water-polygons-split-3857/water_polygons.shp",
  url: "https://osmdata.openstreetmap.de/download/water-polygons-split-3857.zip"
},{
  check: "data/ne_110m_admin_0_boundary_lines_land/ne_110m_admin_0_boundary_lines_land.shp",
  url: "https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip"
}, {
  check: "data/antarctica-icesheet-polygons-3857/icesheet_polygons.shp",
  url: "https://osmdata.openstreetmap.de/download/antarctica-icesheet-polygons-3857.zip"
}, {
  check: "data/antarctica-icesheet-outlines-3857/icesheet_outlines.shp",
  url: "https://osmdata.openstreetmap.de/download/antarctica-icesheet-outlines-3857.zip"
}]

# OSM2PGSQL Node Cache Size in Megabytes
# Default is 800 MB.
default[:maps_server][:openstreetmap_carto][:node_cache_size] = 1600

# Number of processes to use for osm2pgsql import.
# Should match number of threads/cores.
default[:maps_server][:openstreetmap_carto][:import_procs] = 12

###################################
## Default Location for Web Clients
###################################
# This location is Calgary, Canada
default[:maps_server][:openstreetmap_carto][:latitude] = 51.0452
default[:maps_server][:openstreetmap_carto][:longitude] = -114.0625
default[:maps_server][:openstreetmap_carto][:zoom] = 4

###########################
## Monitoring Configuration
###########################
# Be sure to concatenate to merge with other stylesheets
default[:maps_server][:munin_planet_age][:files] += [{
  label:     "osm-extract",
  name:      "/srv/data/extract/openstreetmap-carto-merged.pbf",
  title:     "OpenStreetMap Extract",
  # Measure extract age in days instead of seconds
  frequency: 24 * 60 * 60,
  # Warn at 1.05 years old
  warning:   1.05 * 365,
  # Critical warn at 1.1 years old
  critical:  1.1 * 365
}]