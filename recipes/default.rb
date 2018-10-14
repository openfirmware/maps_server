#
# Cookbook:: maps_server
# Recipe:: default
#
# Copyright:: 2018, James Badger, Apache-2.0 License.

# Set locale
locale 'en_US'

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

# Install mapnik
package %w(libmapnik3.0 libmapnik-dev mapnik-utils python3-mapnik)

# Install mod_tile
mod_tile_path = "#{Chef::Config[:file_cache_path]}/mod_tile"
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

execute 'mod_tile: ldconfig' do
  command 'ldconfig'
end

# Download Extract
extract_url = node['maps_server']['extract_url']
extract_checksum_url = node['maps_server']['extract_checksum_url']

directory "/opt/extract" do
  action :create
end

extract_file = "/opt/extract/#{::File.basename(extract_url)}"
remote_file extract_file do
  source extract_url
  action :create_if_missing
end

if !(extract_checksum_url.nil? || extract_checksum_url.empty?)
  extract_checksum_file = "/opt/extract/#{::File.basename(extract_checksum_url)}"
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

# Install openstreetmap-carto
osm_carto_path = "/opt/openstreetmap-carto"
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
    mkdir #{basename}
    tar -C #{basename} -x -z -f #{file} --xform='s/^.+\///x'
    mv #{basename}/* #{install_directory}
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
    mkdir #{basename}
    unzip -j -d #{basename} #{file}
    mv #{basename}/* #{install_directory}
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
  download_path = "#{Chef::Config[:file_cache_path]}/#{filename}"

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
  check: "#{osm_carto_path}/data/world_bnd_m.shp",
  url: "https://planet.openstreetmap.org/historical-shapefiles/world_boundaries-spherical.tgz"
},
{
  check: "#{osm_carto_path}/data/simplified_land_polygons.shp",
  url: "http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip"
},{
  check: "#{osm_carto_path}/data/ne_110m_admin_0_boundary_lines_land.shp",
  url: "http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip"
}, {
  check: "#{osm_carto_path}/data/land_polygons.shp",
  url: "http://data.openstreetmapdata.com/land-polygons-split-3857.zip"
}, {
  check: "#{osm_carto_path}/data/icesheet_polygons.shp",
  url: "http://data.openstreetmapdata.com/antarctica-icesheet-polygons-3857.zip"
}, {
  check: "#{osm_carto_path}/data/icesheet_outlines.shp",
  url: "http://data.openstreetmapdata.com/antarctica-icesheet-outlines-3857.zip"
}]

shapefiles.each do |source|
  install_shapefiles(source[:url], "#{osm_carto_path}/data", source[:check])
end

# Install fonts for stylesheet
package %w(fontconfig fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted fonts-hanazono ttf-unifont)

noto_emoji_path = "#{Chef::Config[:file_cache_path]}/noto-emoji"
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
  notifies :reload, 'service[postgresql]', :immediate
end

# Create database for OSM import
script 'create renderer database user' do
  code <<-EOH
    psql -c 'CREATE ROLE render WITH SUPERUSER LOGIN;'
  EOH
  cwd '/tmp'
  interpreter 'bash'
  user 'postgres'
  only_if "! psql postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='render'\"", user: 'postgres'
end

script 'create OSM database' do
  code <<-EOH
    psql -c "CREATE DATABASE osm WITH OWNER render ENCODING 'UTF-8';"
  EOH
  cwd '/tmp'
  interpreter 'bash'
  user 'postgres'
  only_if "! psql postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='osm'\"", user: 'postgres'
end

script 'update OSM database' do
  code <<-EOH
    psql osm -c "CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS hstore;
    ALTER TABLE geometry_columns OWNER TO render;
    ALTER TABLE spatial_ref_sys OWNER TO render;"
  EOH
  cwd '/tmp'
  interpreter 'bash'
  user 'postgres'
end

# Add render user
user 'render' do
  comment 'Rendering backend user'
  home '/home/render'
  manage_home true
  shell '/bin/false'
end

# TODO: Crop extract to smaller region

# Load data into database
script "import extract" do
  code <<-EOH
    sudo -u render osm2pgsql --host /var/run/postgresql --create --slim --drop \
              --database osm --username render -C 2500 \
              --tag-transform-script /opt/openstreetmap-carto/openstreetmap-carto.lua \
              --number-processes 4 --style /opt/openstreetmap-carto/openstreetmap-carto.style \
              --hstore -E 4326 -G #{extract_file} &&
    date > /opt/extract/last-import
  EOH
  cwd '/opt'
  interpreter 'bash'
  user 'root'
  timeout 3600
  not_if { ::File.exists?('/opt/extract/last-import') }
end

# TODO: Set up additional PostgreSQL indexes for the stylesheet
# TODO: Optimize PostgreSQL for tile serving
# TODO: Set up raster tile rendering for the stylesheet
# TODO: Deploy a static website with [Leaflet][] for browsing the raster tiles
# TODO: Deploy a static website with [OpenLayers][] for browsing the raster tiles
