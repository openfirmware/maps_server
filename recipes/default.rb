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
  User=#{node['maps_server']['render_user']}
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

# Install openstreetmap-carto.
# We need it for the included tag transform script and style file, which
# are used by the importer.
osm_carto_path = "#{node['maps_server']['stylesheets_prefix']}/openstreetmap-carto"
git osm_carto_path do
  depth 1
  repository 'https://github.com/gravitystorm/openstreetmap-carto'
end

# Optimize PostgreSQL for Imports
import_conf = {}.merge(node['postgresql']['conf'])
                .merge(node['postgresql']['import-conf'])

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
  cwd node['maps_server']['data_prefix']
  live_stream true
  user 'root'
  timeout 3600
  not_if { ::File.exists?("#{node['maps_server']['data_prefix']}/extract/last-import") }
end

script 'clean up database after import' do
  code <<-EOH
    sudo -u #{node['maps_server']['render_user']} psql -d osm -c "VACUUM FULL VERBOSE ANALYZE;" &&
    date > #{node['maps_server']['data_prefix']}/extract/post-import-vacuum
  EOH
  cwd node['maps_server']['data_prefix']
  interpreter 'bash'
  user 'root'
  timeout 3600
  not_if { ::File.exists?("#{node['maps_server']['data_prefix']}/extract/post-import-vacuum") }
end

# Optimize PostgreSQL for tile serving
rendering_conf = {}.merge(node['postgresql']['conf'])
                   .merge(node['postgresql']['tile-conf'])

template '/etc/postgresql/10/main/postgresql.conf' do
  source 'postgresql.conf.erb'
  variables rendering_conf
  notifies :reload, 'service[postgresql]', :immediate
end
