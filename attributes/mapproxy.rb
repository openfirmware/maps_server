# Configuration for MapProxy
# Override this for your configuration in your own cookbook attributes

default[:mapproxy][:repository] = "https://github.com/mapproxy/mapproxy"
default[:mapproxy][:reference] = "master"

# These directories will be created if they do not exist, and ownership
# given to `www-data` so that MapProxy can write caches to them.
default[:mapproxy][:caches][:awm_gpkg] = "/srv/tiles/mapproxy"

# default[:mapproxy][:config] is directly converted into YAML for the 
# configuration. It follows the same structure as the official MapProxy
# config: https://mapproxy.org/docs/1.11.0/configuration.html

default[:mapproxy][:config][:services] = {
  demo: {},
  wmts: {},
  wms: {
    attribution: {
      text: "Map Copyright ArcticConnect, Data Copyright OpenStreetMap Contributors"
    },
    srs: ["EPSG:3573"],
    md: {
      title: "ArcticConnect OWS",
      abstract: "ArcticWebMap tiles via WMS/WMTS.",
      online_resource: "https://webmap.arcticconnect.ca/",
      contact: {
        person: "James Badger",
        position: "Research Associate",
        organization: "GeoSensorWeb Lab",
        address: "2500 University Drive NW",
        city: "Calgary",
        postcode: "T2N1N4",
        state: "Alberta",
        country: "Canada",
        email: "jpbadger@ucalgary.ca"
      },
      access_constraints: "Map tiles are free to use with attribution.",
      fees: "None"
    }
  }
}

default[:mapproxy][:config][:layers] = [{
  name: "awm2",
  title: "ArcticWebMap v2.0 for EPSG:3573",
  # Please note that specifying more than one cache source disables WMTS
  # in MapProxy. To update all the caches, use the seeding tool instead.
  sources: ["awm_gpkg"]
}]

default[:mapproxy][:config][:caches] = {
  # Generate GeoPackage and make it publicly available
  awm_gpkg: {
    grids: ["laea3573"],
    sources: ["awm2_mapnik"],
    cache: {
      type: "geopackage",
      levels: true,
      directory: "#{node[:mapproxy][:caches][:awm_gpkg]}"
    }
  },

  # Generate GeoPackage and make it publicly available. This is a single
  # GeoPackage file containing all the zoom levels.
  awm_gpkg_single: {
    grids: ["laea3573"],
    sources: ["awm2_mapnik"],
    cache: {
      type: "geopackage",
      levels: false,
      filename: "#{node[:mapproxy][:caches][:awm_gpkg]}/laea3573.gpkg"
    }
  }
}

default[:mapproxy][:config][:sources] = {
  awm2_mapnik: {
    type: "mapnik",
    mapfile: "#{node[:maps_server][:stylesheets_prefix]}/arcticwebmap/arcticwebmap.xml"
  }
}

default[:mapproxy][:config][:grids] = {
  laea3573: {
    srs: "EPSG:3573",
    bbox: [-20037508.3427892, -20037508.3427892, 20037508.3427892, 20037508.3427892],
    bbox_srs: "EPSG:3573",
    origin: "ul"
  }
}

default[:mapproxy][:config][:globals] = {}
