#
# Cookbook:: maps_server
# Recipe:: default
#
# Copyright:: 2018–2019, James Badger, Apache-2.0 License.
require "date"

# Set locale
locale node["maps_server"]["locale"]

# Install PostgreSQL
# Use the PostgreSQL Apt repository for latest versions.
apt_repository "postgresql" do
  components    ["main"]
  distribution  "bionic-pgdg"
  key           "https://www.postgresql.org/media/keys/ACCC4CF8.asc"
  uri           "http://apt.postgresql.org/pub/repos/apt/"
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
  variables(:settings => node[:postgresql][:settings][:defaults])
  notifies :reload, "service[postgresql]"
end

directory node["postgresql"]["conf"]["data_directory"] do
  owner "postgres"
  group "postgres"
  mode "700"
  recursive true
  action :create
end

# Move the default database data directory to location defined in
# attributes
execute "move data directory" do
  command "cp -rp /var/lib/postgresql/11/main/* #{node["postgresql"]["conf"]["data_directory"]}/"
  only_if { ::Dir.empty?(node["postgresql"]["conf"]["data_directory"]) }
  notifies :restart, "service[postgresql]", :immediate
end

# Install GDAL
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
directory node["maps_server"]["software_prefix"] do
  recursive true
  action :create
end

mod_tile_path = "#{node["maps_server"]["software_prefix"]}/mod_tile"
git mod_tile_path do
  depth 1
  repository "https://github.com/openstreetmap/mod_tile"
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
  User=#{node["maps_server"]["render_user"]}
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

# Download Extracts

extract_path = "#{node["maps_server"]["data_prefix"]}/extract"
directory extract_path do
  recursive true
  action :create
end

# Collect the downloaded extracts file paths
extract_file_list = []

node["maps_server"]["extracts"].each do |extract|
  extract_url          = extract["extract_url"]
  extract_checksum_url = extract["extract_checksum_url"]
  extract_file         = "#{extract_path}/#{::File.basename(extract_url)}"
  extract_file_list.push(extract_file)

  # Download the extract
  # Only runs if a) a downloaded file doesn't exist, 
  # b) a date requirement for the extract hasn't been set,
  # c) The remote file is newer than the extract date requirement
  remote_file extract_file do
    source extract_url
    only_if {
      edate = extract["extract_date_requirement"]
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
        edate = extract["extract_date_requirement"]
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


# Create stylesheets directory
directory node["maps_server"]["stylesheets_prefix"] do
  recursive true
  action :create
end

# Install openstreetmap-carto.
# We need it for the included tag transform script and style file, which
# are used by the importer.
osm_carto_path = "#{node["maps_server"]["stylesheets_prefix"]}/openstreetmap-carto"
git osm_carto_path do
  depth 1
  repository "https://github.com/gravitystorm/openstreetmap-carto"
end

# Optimize PostgreSQL for Imports
import_conf = {}.merge(node["postgresql"]["settings"]["defaults"])
                .merge(node["postgresql"]["settings"]["import"])

template "/etc/postgresql/11/main/postgresql.conf" do
  source "postgresql.conf.erb"
  variables import_conf
  not_if { ::File.exists?("#{node["maps_server"]["data_prefix"]}/extract/last-import") }
  notifies :reload, "service[postgresql]", :immediate
end

# Create database for OSM import
script "create renderer database user" do
  code <<-EOH
    psql -c "CREATE ROLE #{node["maps_server"]["render_user"]} WITH SUPERUSER LOGIN;"
  EOH
  cwd "/tmp"
  interpreter "bash"
  user "postgres"
  not_if "psql postgres -c \"SELECT rolname FROM pg_roles;\" | grep \"#{node["maps_server"]["render_user"]}\"", user: "postgres"
end

script "create OSM database" do
  code <<-EOH
    psql -c "CREATE DATABASE osm WITH OWNER #{node["maps_server"]["render_user"]} ENCODING 'UTF-8';"
  EOH
  cwd "/tmp"
  interpreter "bash"
  user "postgres"
  not_if "psql postgres -c \"SELECT datname FROM pg_database;\" | grep 'osm'", user: "postgres"
end

script "update OSM database" do
  code <<-EOH
    psql osm -c "CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS hstore;
    ALTER TABLE geometry_columns OWNER TO #{node["maps_server"]["render_user"]};
    ALTER TABLE spatial_ref_sys OWNER TO #{node["maps_server"]["render_user"]};"
  EOH
  cwd "/tmp"
  interpreter "bash"
  user "postgres"
end

# Add render user
user node["maps_server"]["render_user"] do
  comment "Rendering backend user"
  home "/home/#{node["maps_server"]["render_user"]}"
  manage_home true
  shell "/bin/false"
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
extract_bounding_box = node["osm2pgsql"]["crop_bounding_box"]
if !extract_bounding_box.nil? && !extract_bounding_box.empty?
  extract_argument = "--bbox " + extract_bounding_box.join(",")
end

# Load data into database
last_import_file = "#{node["maps_server"]["data_prefix"]}/extract/last-import"

execute "import extract" do
  command <<-EOH
    sudo -u #{node["maps_server"]["render_user"]} osm2pgsql \
              --host /var/run/postgresql --create --slim --drop \
              --username #{node["maps_server"]["render_user"]} \
              --database osm -C #{node["osm2pgsql"]["node_cache_size"]} \
              #{extract_argument} \
              --tag-transform-script #{node["maps_server"]["stylesheets_prefix"]}/openstreetmap-carto/openstreetmap-carto.lua \
              --style #{node["maps_server"]["stylesheets_prefix"]}/openstreetmap-carto/openstreetmap-carto.style \
              --number-processes #{node["osm2pgsql"]["import_procs"]} \
              --hstore -E 4326 -G #{merged_extract} &&
    date > #{last_import_file}
  EOH
  cwd node["maps_server"]["data_prefix"]
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
post_import_vacuum_file = "#{node["maps_server"]["data_prefix"]}/extract/post-import-vacuum"
script "clean up database after import" do
  code <<-EOH
    sudo -u #{node["maps_server"]["render_user"]} psql -d osm -c "VACUUM FULL VERBOSE ANALYZE;" &&
    date > #{post_import_vacuum_file}
  EOH
  cwd node["maps_server"]["data_prefix"]
  interpreter "bash"
  user "root"
  timeout 7200
  not_if { 
    ::File.exists?(post_import_vacuum_file)
  }
end

# Optimize PostgreSQL for tile serving
rendering_conf = {}.merge(node["postgresql"]["settings"]["defaults"])
                   .merge(node["postgresql"]["settings"]["tiles"])

template "/etc/postgresql/11/main/postgresql.conf" do
  source "postgresql.conf.erb"
  variables rendering_conf
  notifies :reload, "service[postgresql]", :immediate
end
