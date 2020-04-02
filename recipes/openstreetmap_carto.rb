#
# Cookbook:: maps_server
# Recipe:: openstreetmap-carto
#
# Copyright:: 2018–2020, James Badger, Apache-2.0 License.

carto_settings = node[:maps_server][:openstreetmap_carto]

# Create stylesheets directory
directory node[:maps_server][:stylesheets_prefix] do
  recursive true
  action :create
end

# Install openstreetmap-carto
osm_carto_path = "#{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto"
git osm_carto_path do
  depth 1
  repository carto_settings[:git_repo]
  reference carto_settings[:git_ref]
end

###################
# Download Extracts
###################
extract_path = "#{node[:maps_server][:data_prefix]}/extract"
directory extract_path do
  recursive true
  action :create
end

# Collect the downloaded extracts file paths
extract_file_list = []

carto_settings[:extracts].each do |extract|
  extract_url          = extract[:extract_url]
  extract_checksum_url = extract[:extract_checksum_url]
  extract_file         = "#{extract_path}/#{::File.basename(extract_url)}"
  extract_file_list.push(extract_file)

  # Download the OSM Database extract
  # Only runs if:
  # a) a downloaded file doesn't exist, OR 
  # b) a date requirement for the extract has been set AND
  #    the downloaded file is older than the extract date requirement
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
  # Only runs if:
  # a) a downloaded checksum file doesn't exist, OR 
  # b) a date requirement for the extract has been set AND
  #    the downloaded checksum file is older than the extract date 
  #    requirement
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

# Store the latest extract date from the attributes in a variable. This
# will be used in later resources to determine if they need to be 
# re-ran.
# We use an initial reduce Time instance with value of "2000-01-01" else
# the reduce loop uses the first value of the array (a Hash) and that
# fails when it is compared to a Time.
latest_extract_time = carto_settings[:extracts].reduce(Time.parse("2000-01-01")) do |memo, extract|
  # Parse the date string into a Time object for comparisons
  edate =  DateTime.strptime(extract[:extract_date_requirement]).to_time
  if memo < edate
    edate
  else
    memo
  end
end

##################################
# Optimize PostgreSQL for Imports.
##################################
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

maps_server_database carto_settings[:database_name] do
  cluster "11/main"
  owner node[:maps_server][:render_user]
end

maps_server_extension "postgis" do
  cluster "11/main"
  database carto_settings[:database_name]
end

maps_server_extension "hstore" do
  cluster "11/main"
  database carto_settings[:database_name]
end

%w[geography_columns planet_osm_nodes planet_osm_rels planet_osm_ways raster_columns raster_overviews spatial_ref_sys].each do |table|
  maps_server_table table do
    cluster "11/main"
    database carto_settings[:database_name]
    owner node[:maps_server][:render_user]
    permissions node[:maps_server][:render_user] => :all
  end
end

###################
# Import Extract(s)
###################
# Join extracts into one large extract file
package "osmosis"

osmosis_args = extract_file_list.collect { |f| "--read-pbf-fast #{f}" }.join(" ")
osmosis_args += " " + (["--merge"] * (extract_file_list.length - 1)).join(" ")
merged_extract = "#{extract_path}/openstreetmap-carto-merged.pbf"

# Use `osmosis` tool to combine OSM PBF files, so only a single import
# using osm2pgsql is needed.
# Only runs if:
# a) a merged extract file doesn't exist, OR 
# b) a date requirement for the extracts has been set AND
#    the merged extract file is older than the extract date requirement
execute "combine extracts" do
  command "osmosis #{osmosis_args} --write-pbf \"#{merged_extract}\""
  timeout 3600
  only_if {
    !::File.exists?(merged_extract) ||
    !latest_extract_time.nil? && ::File.mtime(merged_extract) < latest_extract_time
  }
end

# Crop extract to smaller region, if a bounding box has been defined in
# the attributes.
extract_argument = ""
extract_bounding_box = carto_settings[:crop_bounding_box]
if !extract_bounding_box.nil? && !extract_bounding_box.empty?
  extract_argument = "--bbox " + extract_bounding_box.join(",")
end

# Load data into database using `osm2pgsql`.
# A plain text file with the date of last import is used to record the
# last import time. This is usually bottlenecked by the RAM and disk
# IO speed.
# Only runs if:
# a) a last import file doesn't exist, OR 
# b) a date requirement for the extract has been set AND
#    the last import file is older than the extract date requirement
last_import_file = "#{node[:maps_server][:data_prefix]}/extract/openstreetmap-carto-last-import"

execute "import extract" do
  command <<-EOH
    sudo -u #{node[:maps_server][:render_user]} osm2pgsql \
              --host /var/run/postgresql --create --slim --drop \
              --username #{node[:maps_server][:render_user]} \
              --database #{carto_settings[:database_name]} -C #{carto_settings[:node_cache_size]} \
              #{extract_argument} \
              --tag-transform-script #{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/openstreetmap-carto.lua \
              --style #{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/openstreetmap-carto.style \
              --number-processes #{carto_settings[:import_procs]} \
              --hstore -E 3857 -G #{merged_extract} &&
    date > #{last_import_file}
  EOH
  cwd node[:maps_server][:data_prefix]
  live_stream true
  user "root"
  timeout 86400
  notifies :create, 'template[import-configuration]', :before
  only_if {
    !::File.exists?(last_import_file) ||
    !latest_extract_time.nil? && ::File.mtime(last_import_file) < latest_extract_time
  }
end

# Clean up the database by running a PostgreSQL VACUUM and ANALYZE.
# These improve performance and disk space usage, and therefore queries 
# for generating tiles.
# This should not take very long for small extracts (city/province
# level). Continent/planet level databases will probably have to
# increase the timeout. This is usually bottlenecked by the RAM and disk
# IO speed.
# Only runs if:
# a) a "post-import vacuum" file doesn't exist, OR 
# b) a date requirement for the extract has been set AND
#    the "post-import vacuum" file is older than the extract date 
#    requirement
post_import_vacuum_file = "#{node[:maps_server][:data_prefix]}/extract/openstreetmap-carto-post-import-vacuum"

# Create the post-import vacuum file by notification
file post_import_vacuum_file do
  action :nothing
end

maps_server_execute "VACUUM FULL VERBOSE ANALYZE" do
  cluster "11/main"
  database carto_settings[:database_name]
  timeout 86400
  notifies :touch, "file[#{post_import_vacuum_file}]"
  only_if {
    !::File.exists?(post_import_vacuum_file) ||
    !latest_extract_time.nil? && ::File.mtime(post_import_vacuum_file) < latest_extract_time
  }
end

# Optimize PostgreSQL for tile serving
rendering_conf = node[:postgresql][:settings][:defaults].merge(node[:postgresql][:settings][:tiles])

template "tiles-configuration" do
  path "/etc/postgresql/11/main/postgresql.conf"
  source "postgresql.conf.erb"
  variables(settings: rendering_conf)
  notifies :reload, "service[postgresql]", :immediate
end

############################################
# Install shapefiles for openstreetmap-carto
############################################
package "unzip"

directory "#{osm_carto_path}/data" do
  action :create
end

# Install files from a gzipped tar file into a install directory.
# tar will extract all contents into a single directory, ignoring any
# directory structure inside the archive.
# If `check_file` already exists, then it will not run.
def install_tgz(file, install_directory, check_file)
  basename = ::File.basename(file, ".tgz")

  script "install #{file}" do
    cwd ::File.dirname(file)
    code <<-EOH
    mkdir -p #{basename} &&
    tar -C #{install_directory} -x -z -f #{file} &&
    cp -r #{basename} #{install_directory}/.
    EOH
    not_if { !check_file.nil? && !check_file.empty? && ::File.exists?(check_file) }
    group "root"
    interpreter "bash"
    user "root"
  end
end

# Install files from a zip file into a install directory.
# zip will use -j to extract contents into a single directory, so zip
# files that do or don't put their contents in a directory don't matter.
# If `check_file` already exists, then it will not run.
def install_zip(file, install_directory, check_file)
  basename = ::File.basename(file, ".zip")

  script "install #{file}" do
    cwd ::File.dirname(file)
    code <<-EOH
    mkdir -p #{basename} &&
    unzip -j -o -d #{basename} #{file} &&
    cp -r #{basename} #{install_directory}/.
    EOH
    not_if { !check_file.nil? && !check_file.empty? && ::File.exists?(check_file) }
    group "root"
    interpreter "bash"
    user "root"
  end
end

# Download an archive from `url`, extract its contents, and move the
# contents into `install_directory`.
# If the downloaded archive file exists, the download step is skipped.
# If `check_file` exists, the extraction/move step is skipped.
def install_shapefiles(url, install_directory, check_file)
  filename = ::File.basename(url)
  download_path = "#{node[:maps_server][:data_prefix]}/#{filename}"

  remote_file download_path do
    source url
    action :create_if_missing
  end

  extension = ::File.extname(filename)
  case extension
    when ".tgz"
      install_tgz(download_path, install_directory, check_file)
    when ".zip"
      install_zip(download_path, install_directory, check_file)
  end
end

# Specify shapefiles to download and extract.
# check: skip extract step if this file exists
# url: source of archive to download. Will not re-download file.
shapefiles = [{
  check: "#{osm_carto_path}/data/world_boundaries-spherical/world_bnd_m.shp",
  url: "https://planet.openstreetmap.org/historical-shapefiles/world_boundaries-spherical.tgz"
},
{
  check: "#{osm_carto_path}/data/simplified-land-polygons-complete-3857/simplified_land_polygons.shp",
  url: "https://osmdata.openstreetmap.de/download/simplified-land-polygons-complete-3857.zip"
},{
  check: "#{osm_carto_path}/data/ne_110m_admin_0_boundary_lines_land/ne_110m_admin_0_boundary_lines_land.shp",
  url: "https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip"
}, {
  check: "#{osm_carto_path}/data/land-polygons-split-3857/land_polygons.shp",
  url: "https://osmdata.openstreetmap.de/download/land-polygons-split-3857.zip"
}, {
  check: "#{osm_carto_path}/data/antarctica-icesheet-polygons-3857/icesheet_polygons.shp",
  url: "https://osmdata.openstreetmap.de/download/antarctica-icesheet-polygons-3857.zip"
}, {
  check: "#{osm_carto_path}/data/antarctica-icesheet-outlines-3857/icesheet_outlines.shp",
  url: "https://osmdata.openstreetmap.de/download/antarctica-icesheet-outlines-3857.zip"
}]

shapefiles.each do |source|
  install_shapefiles(source[:url], "#{osm_carto_path}/data", source[:check])
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
osm_carto_indexes_file = "#{node[:maps_server][:data_prefix]}/extract/openstreetmap-carto-indexes"

maps_server_execute "#{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/indexes.sql" do
  cluster "11/main"
  database carto_settings[:database_name]
  timeout 86400
  not_if { ::File.exists?(osm_carto_indexes_file) }
end

file osm_carto_indexes_file do
  action :touch
  not_if { ::File.exists?(osm_carto_indexes_file) }
end

#################################################
# Set up raster tile rendering for the stylesheet
#################################################
# Install Node.js for carto
package %w(nodejs npm)

# Update NPM
execute "Update npm" do
  command "npm i -g npm"
  only_if "npm -v | grep -E '^[345]'"
end

# Install carto
execute "Install carto" do
  command "npm i -g carto"
  not_if "which carto"
end

# Update stylesheets with new DB name
script "update DB name in stylesheet" do
  code <<-EOH
  sed -i -e 's/dbname: "gis"/dbname: "#{carto_settings[:database_name]}"/' #{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/project.mml
  EOH
  interpreter "bash"
  user "root"
end

# Compile the cartoCSS stylesheet to mapnik XML
openstreetmap_carto_xml = "#{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/mapnik.xml"
execute "compile openstreetmap-carto" do
  command "carto project.mml > #{openstreetmap_carto_xml}"
  cwd "#{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto"
  not_if { ::File.exists?(openstreetmap_carto_xml) }
end

# Create tiles directory
directory "/srv/tiles" do
  recursive true
  owner node[:maps_server][:render_user]
  action :create
end

directory "/srv/tiles/openstreetmap-carto" do
  recursive true
  owner node[:maps_server][:render_user]
  action :create
end

# Set the normal attributes for this stylesheet to be loaded into the
# renderd configuration
node.normal[:renderd][:stylesheets][:openstreetmap_carto] = {
  description: "openstreetmap-carto",
  host:       "localhost",
  name:       "openstreetmap-carto",
  tiledir:    "/srv/tiles",
  tilesize:    256,
  uri:        carto_settings[:http_path],
  xml:        openstreetmap_carto_xml
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
    configurations: node[:renderd][:stylesheets].values
  )
  notifies :restart, "service[renderd]"
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
  source "apache/tileserver.conf.erb"
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
node.normal[:maps_server][:tile_providers][:openstreetmap_carto] = {
  attribution: "(c) OpenStreetMap contributors, CC-BY-SA",
  bounds: carto_settings[:bounds],
  default: {
    latitude: carto_settings[:latitude],
    longitude: carto_settings[:longitude],
    zoom: carto_settings[:zoom]
  },
  description: "openstreetmap-carto",
  minzoom: 0,
  maxzoom: 22,
  name: "openstreetmap-carto",
  scheme: "xyz",
  srs: "+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +wktext +no_defs",
  srsName: "EPSG:3857",
  tiles: [ carto_settings[:http_path] ]
}

# Tile provider configuration file for Leaflet and OpenLayers
file "/var/www/html/tiles.json" do
  content JSON.pretty_generate(node[:maps_server][:tile_providers].values)
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

