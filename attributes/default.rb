#########
## Locale
#########
default[:maps_server][:locale] = "en_CA"

##################################
## Installation Directory Prefixes
##################################
# For software packages
default[:maps_server][:software_prefix] = "/opt"
# For map source data downloads
default[:maps_server][:data_prefix] = "/srv/data"
# For map stylesheets
default[:maps_server][:stylesheets_prefix] = "/srv/stylesheets"

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
default[:maps_server][:extracts] = [{
  extract_date_requirement: "2018-11-30T11:00:00+01:00",
  extract_url:              "https://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf",
  extract_checksum_url:     "https://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf.md5"
}, {
  extract_date_requirement: "2018-11-30T11:00:00+01:00",
  extract_url:              "https://download.geofabrik.de/north-america/canada/saskatchewan-latest.osm.pbf",
  extract_checksum_url:     "https://download.geofabrik.de/north-america/canada/saskatchewan-latest.osm.pbf.md5"
}]
# Crop the extract to a given bounding box
# Use a blank array or nil for no crop
# Order is the same as used by osm2pgsql:
# min longitude, min latitude, max longitude,
# max latitude
default[:osm2pgsql][:crop_bounding_box] = []
# default[:osm2pgsql][:crop_bounding_box] = [-115, 50, -113, 52]

# OSM2PGSQL Node Cache Size in Megabytes
# Default is 800 MB.
default[:osm2pgsql][:node_cache_size] = 1600

# Number of processes to use for osm2pgsql import.
# Should match number of threads/cores.
default[:osm2pgsql][:import_procs] = 12

#################
## Rendering User
#################
default[:maps_server][:render_user] = "render"

###################################
## Default Location for Web Clients
###################################
# This location is Calgary, Canada
default[:maps_server][:viewers][:latitude] = 51.0452
default[:maps_server][:viewers][:longitude] = -114.0625
default[:maps_server][:viewers][:zoom] = 4
