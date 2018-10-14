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

# Install GDAL
package %w(gdal-bin gdal-data libgdal-dev libgdal20)

# Install PostGIS
package %w(postgresql-10-postgis-2.5 postgresql-10-postgis-2.5-scripts)

# Install osm2pgsql
package 'osm2pgsql'

# Install Apache2
package %w(apache2 apache2-dev)

# Install mapnik
package %w(libmapnik3.0 libmapnik-dev mapnik-utils)

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

# Install openstreetmap-carto
osm_carto_path = "/opt/openstreetmap-carto"
git osm_carto_path do
  depth 1
  repository 'https://github.com/gravitystorm/openstreetmap-carto'
end
