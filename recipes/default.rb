#
# Cookbook:: maps_server
# Recipe:: default
#
# Copyright:: 2018–2019, James Badger, Apache-2.0 License.
require "date"

# Set locale
locale node[:maps_server][:locale]

# Install PostgreSQL
# Use the PostgreSQL Apt repository for latest versions.
apt_repository "postgresql" do
  components    ["main"]
  distribution  "bionic-pgdg"
  key           "https://www.postgresql.org/media/keys/ACCC4CF8.asc"
  uri           "http://apt.postgresql.org/pub/repos/apt/"
end

# Enable Ubuntu src repositories
apt_repository "ubuntu" do
  uri "http://archive.ubuntu.com/ubuntu/"
  distribution "bionic"
  components %w(main restricted universe multiverse)
  deb_src true
end

# Update Apt cache
apt_update "update" do
  action :update
end

package %w(postgresql-11 postgresql-client-11 postgresql-server-dev-11)

service "postgresql" do
  action :nothing
  supports :status => true, :restart => true, :reload => true
end

template "/etc/postgresql/11/main/postgresql.conf" do
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0o644
  variables(settings: node[:postgresql][:settings][:defaults])
  notifies :reload, "service[postgresql]"
end

directory node[:postgresql][:settings][:defaults][:data_directory] do
  owner "postgres"
  group "postgres"
  mode "700"
  recursive true
  action :create
end

# Move the default database data directory to location defined in
# attributes
execute "move data directory" do
  command "cp -rp /var/lib/postgresql/11/main/* #{node[:postgresql][:settings][:defaults][:data_directory]}/"
  only_if { ::Dir.empty?(node[:postgresql][:settings][:defaults][:data_directory]) }
  notifies :restart, "service[postgresql]", :immediate
end

# Install GDAL and libraries from source to get full support
# 
# liblwgeom provides ST_MakeValid and similar, needed for ArcticWebMap 
# install scripts.
package %w(liblwgeom-dev)

bash "custom install libspatialite-dev" do
  code <<-EOH
  apt-get build-dep libspatialite-dev
  apt-get source libspatialite-dev
  cd spatialite-*
  sed -i 's/--enable-lwgeom=no/--enable-lwgeom=yes/g' debian/rules
  dpkg-buildpackage -us -uc
  dpkg -i ../*.deb
  apt-get install -f
  EOH
  cwd "/usr/local/src"
  not_if { node.normal["maps_server"]["built_libspatialite"] }
end

node.normal["maps_server"]["built_libspatialite"] = true

package %w(gdal-bin gdal-data libgdal-dev libgdal20)

# Install PostGIS
package %w(postgresql-11-postgis-2.5 postgresql-11-postgis-2.5-scripts)

# Install osm2pgsql
package "osm2pgsql"

# Install Apache2
package %w(apache2 apache2-dev)

service "apache2" do
  action :nothing
end

# Install mapnik
package %w(libmapnik3.0 libmapnik-dev mapnik-utils python3-mapnik)

# Install mod_tile
directory node[:maps_server][:software_prefix] do
  recursive true
  action :create
end

mod_tile_path = "#{node[:maps_server][:software_prefix]}/mod_tile"
git mod_tile_path do
  depth 1
  repository "https://github.com/openstreetmap/mod_tile"
  reference "master"
end

execute "mod_tile: autogen" do
  command "./autogen.sh"
  cwd mod_tile_path
  user "root"
  group "root"
  not_if { ::File.exist?(File.join(mod_tile_path, "compile")) }
end

execute "mod_tile: configure" do
  command "./configure"
  cwd mod_tile_path
  user "root"
  group "root"
  not_if { ::File.exist?(File.join(mod_tile_path, "config.log")) }
end

execute "mod_tile: make" do
  command "make -j8"
  cwd mod_tile_path
  user "root"
  group "root"
  not_if { ::File.exist?(File.join(mod_tile_path, "src", "mod_tile.slo")) }
end

execute "renderd: install" do
  command "make install"
  cwd mod_tile_path
  user "root"
  group "root"
  not_if { ::File.exist?("/usr/local/bin/renderd") }
end

execute "mod_tile: install" do
  command "make install-mod_tile"
  cwd mod_tile_path
  user "root"
  group "root"
  not_if { ::File.exist?("/usr/lib/apache2/modules/mod_tile.so") }
end

systemd_unit "renderd.service" do
  content <<-EOH
  [Unit]
  Description=Rendering daemon for Mapnik tiles

  [Service]
  User=#{node[:maps_server][:render_user]}
  RuntimeDirectory=renderd
  ExecStart=/usr/local/bin/renderd -f -c /usr/local/etc/renderd.conf

  [Install]
  WantedBy=multi-user.target
  EOH
  action [:create, :enable, :start]
end

service "renderd" do
  action :nothing
end

execute "mod_tile: ldconfig" do
  command "ldconfig"
end

# Add render user
user node[:maps_server][:render_user] do
  comment "renderd backend user"
  home "/home/#{node[:maps_server][:render_user]}"
  manage_home true
  shell "/bin/false"
end
