##################
## arcticwebmap ##
##################

# Source repo and branch/tag/ref
default[:maps_server][:arcticwebmap][:git_ref] = "stable/2.0"
default[:maps_server][:arcticwebmap][:git_repo] = "https://github.com/GeoSensorWebLab/awm-styles"

# Postgres Database to be created and loaded with OSM data
default[:maps_server][:arcticwebmap][:database_name] = "osm_3573"
# mod_tile path under which tiles will be served via Apache
default[:maps_server][:arcticwebmap][:http_path] = "/awm/"
# Recommended bounds (in EPSG:4326) that is sent to map clients
default[:maps_server][:arcticwebmap][:bounds] = [-180, 40, 0, 90]

#########
## NodeJS
#########
default[:maps_server][:arcticwebmap][:nodejs_binaries] = "https://nodejs.org/download/release/v10.20.0/node-v10.20.0-linux-x64.tar.gz"
default[:maps_server][:arcticwebmap][:nodejs_version] = "10.20.0"
default[:maps_server][:arcticwebmap][:nodejs_prefix] = "/opt/nodejs"

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
default[:maps_server][:arcticwebmap][:extracts] = [{
  extract_date_requirement: "2019-04-03T11:00:00+01:00",
  extract_url:              "https://download.geofabrik.de/north-america/canada/nunavut-latest.osm.pbf",
  extract_checksum_url:     "https://download.geofabrik.de/north-america/canada/nunavut-latest.osm.pbf.md5"
}]
# Crop the extract to a given bounding box
# Use a blank array or nil for no crop
# Order is the same as used by osm2pgsql:
# min longitude, min latitude, max longitude,
# max latitude
default[:maps_server][:arcticwebmap][:crop_bounding_box] = []
# default[:osm2pgsql][:crop_bounding_box] = [-115, 50, -113, 52]

# OSM2PGSQL Node Cache Size in Megabytes
# Default is 800 MB.
default[:maps_server][:arcticwebmap][:node_cache_size] = 800

# Number of processes to use for osm2pgsql import.
# Should match number of threads/cores.
default[:maps_server][:arcticwebmap][:import_procs] = 8

###################################
## Default Location for Web Clients
###################################
# This location is Nunavut, Canada.
# Coordinates should be in EPSG:4326.
default[:maps_server][:arcticwebmap][:latitude] = 71
default[:maps_server][:arcticwebmap][:longitude] = -82
default[:maps_server][:arcticwebmap][:zoom] = 5

###########################
## Monitoring Configuration
###########################
# Be sure to concatenate to merge with other stylesheets
default[:maps_server][:munin_planet_age][:files] += [{
  label:     "awm-extract",
  name:      "/srv/data/extract/arcticwebmap-merged.pbf",
  title:     "ArcticWebMap Extract",
  # Measure extract age in days instead of seconds
  frequency: 24 * 60 * 60,
  # Warn at 1.05 years old
  warning:   1.05 * 365,
  # Critical warn at 1.1 years old
  critical:  1.1 * 365
}]