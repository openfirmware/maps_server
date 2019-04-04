#
# Cookbook:: maps_server
# Recipe:: arcticwebmap
#
# Copyright:: 2019, James Badger, Apache-2.0 License.

awm_settings = node[:maps_server][:arcticwebmap]

# Create stylesheets directory
directory node[:maps_server][:stylesheets_prefix] do
  owner node[:maps_server][:render_user]
  recursive true
  action :create
end

# Install ArcticWebMap
awm_path = "#{node[:maps_server][:stylesheets_prefix]}/arcticwebmap"
git awm_path do
  depth 1
  repository awm_settings[:git_repo]
  reference awm_settings[:git_ref]
  enable_submodules true
  user node[:maps_server][:render_user]
end

# Download Extracts

extract_path = "#{node[:maps_server][:data_prefix]}/extract"
directory extract_path do
  recursive true
  action :create
end

# Collect the downloaded extracts file paths
extract_file_list = []

awm_settings[:extracts].each do |extract|
  extract_url          = extract[:extract_url]
  extract_checksum_url = extract[:extract_checksum_url]
  extract_file         = "#{extract_path}/#{::File.basename(extract_url)}"
  extract_file_list.push(extract_file)

  # Download the extract
  # Only runs if a) a downloaded file doesn't exist, 
  # b) a date requirement for the extract hasn't been set,
  # c) The remote file is newer than the extract date requirement
  remote_file extract_file do
    source extract_url
    only_if {
      edate = extract[:extract_date_requirement]
      !::File.exists?(extract_file) ||
      !edate.nil? && !edate.empty? && ::File.mtime(extract_file) < DateTime.strptime(edate).to_time
    }
    action :create
  end

  # If there is a checksum URL, download it and validate the extract
  # against the checksum provided by the source. Assumes md5.
  if !(extract_checksum_url.nil? || extract_checksum_url.empty?)
    extract_checksum_file = "#{extract_path}/#{::File.basename(extract_checksum_url)}"
    remote_file extract_checksum_file do
      source extract_checksum_url
      only_if {
        edate = extract[:extract_date_requirement]
        !::File.exists?(extract_checksum_file) ||
        !edate.nil? && !edate.empty? && ::File.mtime(extract_checksum_file) < DateTime.strptime(edate).to_time
      }
      action :create
    end

    execute "validate extract" do
      command "md5sum --check #{extract_checksum_file}"
      cwd ::File.dirname(extract_checksum_file)
      user "root"
    end
  end
end

# Optimize PostgreSQL for Imports.
# Only activate this configuration if osm2pgsql runs.
import_conf = node[:postgresql][:settings][:defaults].merge(node[:postgresql][:settings][:import])

template "import-configuration" do
  path "/etc/postgresql/11/main/postgresql.conf"
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0o644
  variables(settings: import_conf)
  notifies :reload, "service[postgresql]"
  action :nothing
end

# Create database user for rendering
maps_server_user node[:maps_server][:render_user] do
  cluster "11/main"
  superuser true
end

maps_server_database awm_settings[:database_name] do
  cluster "11/main"
  owner node[:maps_server][:render_user]
end

maps_server_extension "postgis" do
  cluster "11/main"
  database awm_settings[:database_name]
end

maps_server_extension "hstore" do
  cluster "11/main"
  database awm_settings[:database_name]
end

%w[geography_columns planet_osm_nodes planet_osm_rels planet_osm_ways raster_columns raster_overviews spatial_ref_sys].each do |table|
  maps_server_table table do
    cluster "11/main"
    database awm_settings[:database_name]
    owner node[:maps_server][:render_user]
    permissions node[:maps_server][:render_user] => :all
  end
end

# Join extracts into one large extract file
package "osmosis"

osmosis_args = extract_file_list.collect { |f| "--read-pbf-fast #{f}" }.join(" ")
osmosis_args += " " + (["--merge"] * (extract_file_list.length - 1)).join(" ")
merged_extract = "#{extract_path}/arcticwebmap-merged.pbf"

execute "combine extracts" do
  command "osmosis #{osmosis_args} --write-pbf \"#{merged_extract}\""
  timeout 3600
  not_if { ::File.exist?(merged_extract) }
end

# Crop extract to smaller region
extract_argument = ""
extract_bounding_box = awm_settings[:crop_bounding_box]
if !extract_bounding_box.nil? && !extract_bounding_box.empty?
  extract_argument = "--bbox " + extract_bounding_box.join(",")
end

# Load data into database
last_import_file = "#{node[:maps_server][:data_prefix]}/extract/arcticwebmap-last-import"

execute "import extract" do
  command <<-EOH
    sudo -u #{node[:maps_server][:render_user]} osm2pgsql \
              --host /var/run/postgresql --create --slim --drop \
              --username #{node[:maps_server][:render_user]} \
              --database #{awm_settings[:database_name]} -C #{awm_settings[:node_cache_size]} \
              #{extract_argument} \
              --tag-transform-script #{awm_path}/openstreetmap-carto/openstreetmap-carto.lua \
              --style #{awm_path}/openstreetmap-carto/openstreetmap-carto.style \
              --number-processes #{awm_settings[:import_procs]} \
              --hstore -E 3573 -G #{merged_extract} &&
    date > #{last_import_file}
  EOH
  cwd node[:maps_server][:data_prefix]
  live_stream true
  user "root"
  timeout 86400
  notifies :create, 'template[import-configuration]', :before
  not_if { ::File.exists?(last_import_file) }
end

# Clean up the database by running a PostgreSQL VACUUM and ANALYZE.
# These improve performance and disk space usage, and therefore queries 
# for generating tiles.
# This should not take very long for small extracts (city/province
# level). Continent/planet level databases will probably have to
# increase the timeout.
# A timestamp file is created after the run, and used to determine if
# the resource should be re-run.
post_import_vacuum_file = "#{node[:maps_server][:data_prefix]}/extract/arcticwebmap-post-import-vacuum"

maps_server_execute "VACUUM FULL VERBOSE ANALYZE" do
  cluster "11/main"
  database awm_settings[:database_name]
  timeout 86400
  not_if { ::File.exists?(post_import_vacuum_file) }
end


file post_import_vacuum_file do
  action :touch
  not_if { ::File.exists?(post_import_vacuum_file) }
end

# Optimize PostgreSQL for tile serving
rendering_conf = node[:postgresql][:settings][:defaults].merge(node[:postgresql][:settings][:tiles])

template "tiles-configuration" do
  path "/etc/postgresql/11/main/postgresql.conf"
  source "postgresql.conf.erb"
  variables(settings: rendering_conf)
  notifies :reload, "service[postgresql]", :immediate
end

# Install Node.js for stylesheet tools
# TODO: Maybe install a specific version of node to a prefix and use that?
package %w(nodejs npm)

# Update NPM
execute "Update npm" do
  command "npm i -g npm"
  only_if "npm -v | grep -E '^[345]'"
end

execute "install packages for stylesheet" do
  command "npm install"
  env(
    NPM_CONFIG_CACHE: "/home/#{node[:maps_server][:render_user]}/.npm",
    NPM_CONFIG_TMP: "/home/#{node[:maps_server][:render_user]}/tmp"
  )
  cwd awm_path
  user node[:maps_server][:render_user]
  not_if { ::Dir.exists?("#{awm_path}/node_modules") }
end

# Create data directory inside openstreetmap-carto, as it does not
# automatically exist because of .gitignore
directory "#{awm_path}/openstreetmap-carto/data" do
  owner node[:maps_server][:render_user]
  recursive true
  action :create
end

# Create directory to store transformed vector/raster data. (A separate
# directory resource is required as "recursive" only applies ownership
# to the final directory.)
directory "#{awm_path}/openstreetmap-carto/data/awm" do
  owner node[:maps_server][:render_user]
  recursive true
  action :create
end

execute "install shapefiles/rasters" do
  command "node scripts/get-datafiles.js"
  cwd awm_path
  env(
    NPM_CONFIG_CACHE: "/home/#{node[:maps_server][:render_user]}/.npm",
    NPM_CONFIG_TMP: "/home/#{node[:maps_server][:render_user]}/tmp"
  )
  user node[:maps_server][:render_user]
  timeout 3600
end

# create link for shapefile/raster data to be accessible by XML stylesheet
link "#{awm_path}/data" do
  to "#{awm_path}/openstreetmap-carto/data"
  owner node[:maps_server][:render_user]
end

# create link for symbol data to be accessible by XML stylesheet
link "#{awm_path}/symbols" do
  to "#{awm_path}/openstreetmap-carto/symbols"
  owner node[:maps_server][:render_user]
end

# Install fonts for stylesheet
package %w(fontconfig fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted fonts-hanazono ttf-unifont)

noto_emoji_path = "#{node[:maps_server][:software_prefix]}/noto-emoji"
git noto_emoji_path do
  depth 1
  repository "https://github.com/googlei18n/noto-emoji"
  reference "master"
end

script "install noto-emoji" do
  code <<-EOH
  mv fonts/NotoEmoji-Regular.ttf /usr/local/share/fonts/.
  fc-cache -f -v
  EOH
  cwd noto_emoji_path
  interpreter "bash"
  user "root"
  group "root"
  not_if { ::File.exists?("/usr/local/share/fonts/NotoEmoji-Regular.ttf") }
end

# Set up additional PostgreSQL indexes for the stylesheet
awm_indexes_file = "#{node[:maps_server][:data_prefix]}/extract/arcticwebmap-indexes"

maps_server_execute "#{awm_path}/openstreetmap-carto/indexes.sql" do
  cluster "11/main"
  database awm_settings[:database_name]
  timeout 86400
  not_if { ::File.exists?(awm_indexes_file) }
end

file awm_indexes_file do
  action :touch
  not_if { ::File.exists?(awm_indexes_file) }
end

# Set up raster tile rendering for the stylesheet

# Compile the cartoCSS stylesheet to mapnik XML
arcticwebmap_xml = "#{awm_path}/arcticwebmap.xml"
execute "compile awm-styles" do
  command "node scripts/compile.js xml"
  env(
    NPM_CONFIG_CACHE: "/home/#{node[:maps_server][:render_user]}/.npm",
    NPM_CONFIG_TMP: "/home/#{node[:maps_server][:render_user]}/tmp"
  )
  cwd awm_path
  user node[:maps_server][:render_user]
  not_if { ::File.exists?(arcticwebmap_xml) }
end

# Create tiles directory
directory "/srv/tiles" do
  recursive true
  owner node[:maps_server][:render_user]
  action :create
end

directory "/srv/tiles/arcticwebmap" do
  recursive true
  owner node[:maps_server][:render_user]
  action :create
end

# Set the normal attributes for this stylesheet to be loaded into the
# renderd configuration
node.normal[:renderd][:stylesheets][:arcticwebmap] = {
  description: "Canadian Arctic Web Map",
  host:       "localhost",
  name:       "arcticwebmap",
  tiledir:    "/srv/tiles",
  tilesize:    256,
  uri:        awm_settings[:http_path],
  xml:        arcticwebmap_xml
}

# Use normal attributes to read stylesheets as more than one may need
# to be loaded into the renderd configuration.
template "/usr/local/etc/renderd.conf" do
  source "renderd.conf.erb"
  variables(
    num_threads: 4, 
    tile_dir: "/srv/tiles", 
    plugins_dir: "/usr/lib/mapnik/3.0/input",
    font_dir: "/usr/share/fonts",
    configurations: node.normal[:renderd][:stylesheets].values
  )
  notifies :restart, "service[renderd]", :immediate
end

# Install Apache mod_tile loader
cookbook_file "/etc/apache2/mods-available/tile.load" do
  source "mod_tile.load"
  action :create
end

# Enable mod_tile
execute "enable mod_tile" do
  command "a2enmod tile"
  not_if { ::File.exists?("/etc/apache2/mods-enabled/tile.load") }
end

# Disable default apache site
execute "disable default apache site" do
  command "a2dissite 000-default"
  only_if { ::File.exists?("/etc/apache2/sites-enabled/000-default.conf") }
end

# Create apache virtualhost for tile server
template "/etc/apache2/sites-available/tileserver.conf" do
  source "tileserver.conf.erb"
end

execute "enable tileserver apache site" do
  command "a2ensite tileserver"
  not_if { ::File.exists?("/etc/apache2/sites-enabled/tileserver.conf") }
  notifies :reload, "service[apache2]", :immediate
end

# A second reload of Apache is needed, for some unknown reason.
service "apache2" do
  action :reload
end

# Set the normal attributes for this tile provider to be loaded into the
# Leaflet/OpenLayers configuration
node.normal[:maps_server][:tile_providers][:arcticwebmap] = {
  attribution: "(c) OpenStreetMap contributors, CC-BY-SA",
  bounds: awm_settings[:bounds],
  default: {
    latitude: awm_settings[:latitude],
    longitude: awm_settings[:longitude],
    zoom: awm_settings[:zoom]
  },
  description: "Canadian Arctic Web Map",
  minzoom: 0,
  maxzoom: 22,
  name: "arcticwebmap",
  scheme: "xyz",
  srs: "+proj=laea +lat_0=90 +lon_0=-100 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs",
  srsName: "EPSG:3573",
  tiles: [ awm_settings[:http_path] ]
}

# Tile provider configuration file for Leaflet and OpenLayers
file "/var/www/html/tiles.json" do
  content JSON.pretty_generate(node.normal[:maps_server][:tile_providers].values)
end

# Deploy a static website with Leaflet for browsing the raster tiles
template "/var/www/html/leaflet.html" do
  source "leaflet.html.erb"
end

# Deploy a static website with OpenLayers for browsing the raster tiles
template "/var/www/html/openlayers.html" do
  source "openlayers.html.erb"
end

service "renderd" do
  action :restart
end

