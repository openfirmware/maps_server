#
# Cookbook:: maps_server
# Recipe:: openstreetmap-carto
#
# Copyright:: 2018–2019, James Badger, Apache-2.0 License.

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
  repository "https://github.com/gravitystorm/openstreetmap-carto"
  reference "v4.20.0"
end

# Download Extracts

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

# Optimize PostgreSQL for Imports
import_conf = node[:postgresql][:settings][:defaults].merge(node[:postgresql][:settings][:import])

template "/etc/postgresql/11/main/postgresql.conf" do
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0o644
  variables(settings: import_conf)
  notifies :reload, "service[postgresql]"
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

# Join extracts into one large extract file
package "osmosis"

osmosis_args = extract_file_list.collect { |f| "--read-pbf-fast #{f}" }.join(" ")
osmosis_args += " " + (["--merge"] * (extract_file_list.length - 1)).join(" ")
merged_extract = "#{extract_path}/merged.pbf"

execute "combine extracts" do
  command "osmosis #{osmosis_args} --write-pbf \"#{merged_extract}\""
  timeout 3600
  not_if { ::File.exist?(merged_extract) }
end

# Crop extract to smaller region
extract_argument = ""
extract_bounding_box = carto_settings[:crop_bounding_box]
if !extract_bounding_box.nil? && !extract_bounding_box.empty?
  extract_argument = "--bbox " + extract_bounding_box.join(",")
end

# Load data into database
last_import_file = "#{node[:maps_server][:data_prefix]}/extract/openstreetmap-carto-last-import"

execute "import extract" do
  command <<-EOH
    sudo -u #{node[:maps_server][:render_user]} osm2pgsql \
              --host /var/run/postgresql --create --slim --drop \
              --username #{node[:maps_server][:render_user]} \
              --database osm -C #{carto_settings[:node_cache_size]} \
              #{extract_argument} \
              --tag-transform-script #{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/openstreetmap-carto.lua \
              --style #{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/openstreetmap-carto.style \
              --number-processes #{carto_settings[:import_procs]} \
              --hstore -E 4326 -G #{merged_extract} &&
    date > #{last_import_file}
  EOH
  cwd node[:maps_server][:data_prefix]
  live_stream true
  user "root"
  timeout 86400
  not_if { 
    ::File.exists?(last_import_file)
  }
end

# Clean up the database by running a PostgreSQL VACUUM and ANALYZE.
# These improve performance and disk space usage, and therefore queries 
# for generating tiles.
# This should not take very long for small extracts (city/province
# level). Continent/planet level databases will probably have to
# increase the timeout.
# A timestamp file is created after the run, and used to determine if
# the resource should be re-run.
post_import_vacuum_file = "#{node[:maps_server][:data_prefix]}/extract/openstreetmap-carto-post-import-vacuum"

maps_server_execute "VACUUM FULL VERBOSE ANALYZE" do
  cluster "11/main"
  database carto_settings[:database_name]
  not_if { ::File.exists?(post_import_vacuum_file) }
end


file post_import_vacuum_file do
  action :touch
  not_if { ::File.exists?(post_import_vacuum_file) }
end

# Optimize PostgreSQL for tile serving
rendering_conf = node[:postgresql][:settings][:defaults].merge(node[:postgresql][:settings][:tiles])

template "/etc/postgresql/11/main/postgresql.conf" do
  source "postgresql.conf.erb"
  variables(settings: rendering_conf)
  notifies :reload, "service[postgresql]", :immediate
end

# Install shapefiles for openstreetmap-carto
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
  url: "http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip"
},{
  check: "#{osm_carto_path}/data/ne_110m_admin_0_boundary_lines_land/ne_110m_admin_0_boundary_lines_land.shp",
  url: "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip"
}, {
  check: "#{osm_carto_path}/data/land-polygons-split-3857/land_polygons.shp",
  url: "http://data.openstreetmapdata.com/land-polygons-split-3857.zip"
}, {
  check: "#{osm_carto_path}/data/antarctica-icesheet-polygons-3857/icesheet_polygons.shp",
  url: "http://data.openstreetmapdata.com/antarctica-icesheet-polygons-3857.zip"
}, {
  check: "#{osm_carto_path}/data/antarctica-icesheet-outlines-3857/icesheet_outlines.shp",
  url: "http://data.openstreetmapdata.com/antarctica-icesheet-outlines-3857.zip"
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
  not_if { ::File.exists?(osm_carto_indexes_file) }
end

file osm_carto_indexes_file do
  action :touch
  not_if { ::File.exists?(osm_carto_indexes_file) }
end

# Set up raster tile rendering for the stylesheet

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

# Update stylesheet to use EPSG:4326 for OSM data
execute "update projection in stylesheet" do
  command %Q[perl -i -0pe 's/extents(\\s+Datasource:\\s+<<: \\*osm2pgsql)/extents84$1/g' #{node[:maps_server][:stylesheets_prefix]}/openstreetmap-carto/project.mml]
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

# Update renderd configuration for openstreetmap-carto
styles = [{
  name: "openstreetmap-carto",
  uri: carto_settings[:http_path],
  tiledir: "/srv/tiles",
  xml: openstreetmap_carto_xml,
  host: "localhost",
  tilesize: 256,
  description: "openstreetmap-carto"
}]

template "/usr/local/etc/renderd.conf" do
  source "renderd.conf.erb"
  variables(
    num_threads: 4, 
    tile_dir: "/srv/tiles", 
    plugins_dir: "/usr/lib/mapnik/3.0/input",
    font_dir: "/usr/share/fonts",
    configurations: styles
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

# Deploy a static website with Leaflet for browsing the raster tiles
template "/var/www/html/leaflet.html" do
  source "leaflet.html.erb"
  variables(latitude: carto_settings[:latitude], 
            longitude: carto_settings[:longitude],
            zoom: carto_settings[:zoom])
end

# Deploy a static website with OpenLayers for browsing the raster tiles
template "/var/www/html/openlayers.html" do
  source "openlayers.html.erb"
  variables(latitude: carto_settings[:latitude], 
            longitude: carto_settings[:longitude],
            zoom: carto_settings[:zoom])
end

service "renderd" do
  action :restart
end

