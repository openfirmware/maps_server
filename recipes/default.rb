#
# Cookbook:: maps_server
# Recipe:: default
#
# Copyright:: 2018, James Badger, Apache-2.0 License.

# Set locale
locale node['maps_server']['locale']

# Install PostgreSQL
# Use the PostgreSQL Apt repository for latest versions.
apt_repository 'postgresql' do
  components    ['main']
  distribution  'bionic-pgdg'
  key           'https://www.postgresql.org/media/keys/ACCC4CF8.asc'
  uri           'http://apt.postgresql.org/pub/repos/apt/'
end

# Update Apt cache
apt_update 'update' do
  action :update
end

package %w(postgresql-10 postgresql-client-10 postgresql-contrib libpq-dev)

service 'postgresql' do
  action :nothing
end

# Install GDAL
package %w(gdal-bin gdal-data libgdal-dev libgdal20)

# Install PostGIS
package %w(postgresql-10-postgis-2.5 postgresql-10-postgis-2.5-scripts)

# Install osm2pgsql
package 'osm2pgsql'

# Install Apache2
package %w(apache2 apache2-dev)

service 'apache2' do
  action :nothing
end

# Install mapnik
package %w(libmapnik3.0 libmapnik-dev mapnik-utils python3-mapnik)

# Install mod_tile
directory node['maps_server']['software_prefix'] do
  recursive true
  action :create
end

mod_tile_path = "#{node['maps_server']['software_prefix']}/mod_tile"
git mod_tile_path do
  depth 1
  repository 'https://github.com/openstreetmap/mod_tile'
end

execute 'mod_tile: autogen' do
  command './autogen.sh'
  cwd mod_tile_path
  user 'root'
  group 'root'
  not_if { ::File.exist?(File.join(mod_tile_path, 'compile')) }
end

execute 'mod_tile: configure' do
  command './configure'
  cwd mod_tile_path
  user 'root'
  group 'root'
  not_if { ::File.exist?(File.join(mod_tile_path, 'config.log')) }
end

execute 'mod_tile: make' do
  command 'make -j8'
  cwd mod_tile_path
  user 'root'
  group 'root'
  not_if { ::File.exist?(File.join(mod_tile_path, 'src', 'mod_tile.slo')) }
end

execute 'renderd: install' do
  command 'make install'
  cwd mod_tile_path
  user 'root'
  group 'root'
  not_if { ::File.exist?('/usr/local/bin/renderd') }
end

execute 'mod_tile: install' do
  command 'make install-mod_tile'
  cwd mod_tile_path
  user 'root'
  group 'root'
  not_if { ::File.exist?('/usr/lib/apache2/modules/mod_tile.so') }
end

systemd_unit 'renderd.service' do
  content <<-EOH
  [Unit]
  Description=Rendering daemon for Mapnik tiles

  [Service]
  User=render
  RuntimeDirectory=renderd
  ExecStart=/usr/local/bin/renderd -f -c /usr/local/etc/renderd.conf

  [Install]
  WantedBy=multi-user.target
  EOH
  action [:create, :enable, :start]
end

service 'renderd' do
  action :nothing
end

execute 'mod_tile: ldconfig' do
  command 'ldconfig'
end

# Download Extract
extract_url = node['maps_server']['extract_url']
extract_checksum_url = node['maps_server']['extract_checksum_url']

extract_path = "#{node['maps_server']['data_prefix']}/extract"
directory extract_path do
  recursive true
  action :create
end

extract_file = "#{extract_path}/#{::File.basename(extract_url)}"
remote_file extract_file do
  source extract_url
  action :create_if_missing
end

if !(extract_checksum_url.nil? || extract_checksum_url.empty?)
  extract_checksum_file = "#{extract_path}/#{::File.basename(extract_checksum_url)}"
  remote_file extract_checksum_file do
    source extract_checksum_url
    action :create_if_missing
  end

  execute 'validate extract' do
    command "md5sum --check #{extract_checksum_file}"
    cwd ::File.dirname(extract_checksum_file)
    user 'root'
  end
end

# Create stylesheets directory
directory node['maps_server']['stylesheets_prefix'] do
  recursive true
  action :create
end

# Install openstreetmap-carto
osm_carto_path = "#{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto"
git osm_carto_path do
  depth 1
  repository 'https://github.com/gravitystorm/openstreetmap-carto'
end

# Install shapefiles for openstreetmap-carto
package 'unzip'

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
    group 'root'
    interpreter 'bash'
    user 'root'
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
    unzip -j -d #{basename} #{file} &&
    cp -r #{basename} #{install_directory}/.
    EOH
    not_if { !check_file.nil? && !check_file.empty? && ::File.exists?(check_file) }
    group 'root'
    interpreter 'bash'
    user 'root'
  end
end

# Download an archive from `url`, extract its contents, and move the
# contents into `install_directory`.
# If the downloaded archive file exists, the download step is skipped.
# If `check_file` exists, the extraction/move step is skipped.
def install_shapefiles(url, install_directory, check_file)
  filename = ::File.basename(url)
  download_path = "#{node['maps_server']['data_prefix']}/#{filename}"

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

noto_emoji_path = "#{node['maps_server']['software_prefix']}/noto-emoji"
git noto_emoji_path do
  depth 1
  repository 'https://github.com/googlei18n/noto-emoji'
end

script "install noto-emoji" do
  code <<-EOH
  mv fonts/NotoEmoji-Regular.ttf /usr/local/share/fonts/.
  fc-cache -f -v
  EOH
  cwd noto_emoji_path
  interpreter 'bash'
  user 'root'
  group 'root'
  not_if { ::File.exists?("/usr/local/share/fonts/NotoEmoji-Regular.ttf") }
end

import_conf = {}.merge(node['postgresql']['conf'])
                .merge(node['postgresql']['import-conf'])

# Optimize PostgreSQL for Imports
template '/etc/postgresql/10/main/postgresql.conf' do
  source 'postgresql.conf.erb'
  variables import_conf
  not_if { ::File.exists?("#{node['maps_server']['data_prefix']}/extract/last-import") }
  notifies :reload, 'service[postgresql]', :immediate
end

# Create database for OSM import
script 'create renderer database user' do
  code <<-EOH
    psql -c 'CREATE ROLE #{node['maps_server']['render_user']} WITH SUPERUSER LOGIN;'
  EOH
  cwd '/tmp'
  interpreter 'bash'
  user 'postgres'
  not_if "psql postgres -c \"SELECT rolname FROM pg_roles;\" | grep '#{node['maps_server']['render_user']}'", user: 'postgres'
end

script 'create OSM database' do
  code <<-EOH
    psql -c "CREATE DATABASE osm WITH OWNER #{node['maps_server']['render_user']} ENCODING 'UTF-8';"
  EOH
  cwd '/tmp'
  interpreter 'bash'
  user 'postgres'
  not_if "psql postgres -c \"SELECT datname FROM pg_database;\" | grep 'osm'", user: 'postgres'
end

script 'update OSM database' do
  code <<-EOH
    psql osm -c "CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS hstore;
    ALTER TABLE geometry_columns OWNER TO #{node['maps_server']['render_user']};
    ALTER TABLE spatial_ref_sys OWNER TO #{node['maps_server']['render_user']};"
  EOH
  cwd '/tmp'
  interpreter 'bash'
  user 'postgres'
end

# Add render user
user node['maps_server']['render_user'] do
  comment 'Rendering backend user'
  home "/home/#{node['maps_server']['render_user']}"
  manage_home true
  shell '/bin/false'
end

# TODO: Crop extract to smaller region

# Load data into database
# TODO: Support forced reload of data to refresh database
execute "import extract" do
  command <<-EOH
    sudo -u #{node['maps_server']['render_user']} osm2pgsql \
              --host /var/run/postgresql --create --slim --drop \
              --username #{node['maps_server']['render_user']} \
              --database osm -C 2500 \
              --tag-transform-script #{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto/openstreetmap-carto.lua \
              --style #{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto/openstreetmap-carto.style \
              --number-processes 4 \
              --hstore -E 4326 -G #{extract_file} &&
    date > #{node['maps_server']['data_prefix']}/extract/last-import
  EOH
  cwd node['maps_server']['stylesheets_prefix']
  live_stream true
  user 'root'
  timeout 3600
  not_if { ::File.exists?("#{node['maps_server']['data_prefix']}/extract/last-import") }
end

script 'clean up database after import' do
  code <<-EOH
    sudo -u #{node['maps_server']['render_user']} psql -d osm -c "VACUUM FULL VERBOSE ANALYZE;" &&
    date > #{node['maps_server']['data_prefix']}/extract/openstreetmap-carto-vacuum
  EOH
  cwd node['maps_server']['stylesheets_prefix']
  interpreter 'bash'
  user 'root'
  timeout 3600
  not_if { ::File.exists?("#{node['maps_server']['data_prefix']}/extract/openstreetmap-carto-vacuum") }
end

# Set up additional PostgreSQL indexes for the stylesheet
script 'add indexes for openstreetmap-carto' do
  code <<-EOH
    sudo -u #{node['maps_server']['render_user']} psql -d osm -f "#{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto/indexes.sql" && \
    date > #{node['maps_server']['data_prefix']}/extract/openstreetmap-carto-indexes
  EOH
  cwd node['maps_server']['stylesheets_prefix']
  interpreter 'bash'
  user 'root'
  timeout 3600
  not_if { ::File.exists?("#{node['maps_server']['data_prefix']}/extract/openstreetmap-carto-indexes") }
end


# Optimize PostgreSQL for tile serving
rendering_conf = {}.merge(node['postgresql']['conf'])
                   .merge(node['postgresql']['tile-conf'])

template '/etc/postgresql/10/main/postgresql.conf' do
  source 'postgresql.conf.erb'
  variables rendering_conf
  notifies :reload, 'service[postgresql]', :immediate
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
script 'update DB name in stylesheet' do
  code <<-EOH
  sed -i -e 's/dbname: "gis"/dbname: "osm"/' #{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto/project.mml
  EOH
  interpreter 'bash'
  user 'root'
end

# Compile the cartoCSS stylesheet to mapnik XML
openstreetmap_carto_xml = "#{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto/mapnik.xml"
execute "compile openstreetmap-carto" do
  command "carto project.mml > #{openstreetmap_carto_xml}"
  cwd "#{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto"
  not_if { ::File.exists?(openstreetmap_carto_xml) }
end

# Create tiles directory
directory "/srv/tiles" do
  recursive true
  action :create
end

directory "/srv/tiles/openstreetmap-carto" do
  recursive true
  action :create
end

# Update renderd configuration for openstreetmap-carto
styles = [{
  name: "default",
  uri: "/osm/",
  tiledir: "/srv/tiles/openstreetmap-carto",
  xml: openstreetmap_carto_xml,
  host: "localhost",
  tilesize: 256,
  description: "openstreetmap-carto"
}]

template '/usr/local/etc/renderd.conf' do
  source 'renderd.conf.erb'
  variables(
    num_threads: 4, 
    tile_dir: '/srv/tiles', 
    plugins_dir: "/usr/lib/mapnik/3.0/input",
    font_dir: "/usr/share/fonts",
    configurations: styles
  )
  notifies :reload, 'service[renderd]', :immediate
end

# Install Apache mod_tile loader
cookbook_file '/etc/apache2/mods-available/tile.load' do
  source 'mod_tile.load'
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
  notifies :reload, 'service[apache2]', :immediate
end

# A second reload of Apache is needed, for some unknown reason.
service "apache2" do
  action :reload
end

# TODO: Deploy a static website with [Leaflet][] for browsing the raster tiles
# TODO: Deploy a static website with [OpenLayers][] for browsing the raster tiles
