# Configuration for MapProxy
# Override this for your configuration in your own cookbook attributes

default[:mapproxy][:repository] = "https://github.com/mapproxy/mapproxy"
default[:mapproxy][:reference] = "master"

default[:mapproxy][:caches][:awm] = "/srv/tiles/proxy_cache_awm"

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
    srs: ['EPSG:3573'],
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
  sources: ["awm_cache"]
}]

default[:mapproxy][:config][:caches] = {
  awm_cache: {
    grids: ["laea3573"],
    sources: ["awm2_mapnik"],
    cache: {
      type: "file",
      directory: "#{node[:mapproxy][:caches][:awm]}"
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
