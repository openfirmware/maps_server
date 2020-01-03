#
# Cookbook:: maps_server
# Recipe:: mapproxy
#
# Copyright:: 2019–2020, James Badger, Apache-2.0 License.

###################
# 1. Install Apache
###################
package %w(apache2 apache2-dev)

service "apache2" do
  action :nothing
end


#####################
# 2. Install MapProxy
#####################
package %w(python-pip python-pil python-yaml python-mapnik libproj12 libproj-dev)

mapproxy_home = "#{node[:maps_server][:software_prefix]}/mapproxy"

directory mapproxy_home do
  recursive true
  action :create
end

# Checkout from master as the latest release is from Nov 2017 and there
# are necessary fixes for token problems added to the master branch.
# If a new MapProxy Python package is released, this block can be 
# changed to a pip install resource instead.
git "#{mapproxy_home}/src" do
  repository node[:mapproxy][:repository]
  reference node[:mapproxy][:reference]
end

execute "install mapproxy from source" do
  command "make install"
  cwd "#{mapproxy_home}/src"
end

configuration_path = "#{mapproxy_home}/mapproxy.yaml"

# Note that the attributes hash has to be converted to a Hash in the
# recipe and not the template, or else Ruby Mash (Hash variant) will
# leak into the YAML and MapProxy will fail to read the configuration.
template configuration_path do
  source "mapproxy/config.yaml.erb"
  mode "755"
  variables({
    config: node[:mapproxy][:config].to_hash
  })
  notifies :reload, "service[apache2]"
end

# Deploy a sample Seeding file. Will need to be edited on the server.
template "#{mapproxy_home}/seed.yaml" do
  source "mapproxy/seed.yaml.erb"
  mode "755"
end

# Create Cache Directories
node[:mapproxy][:caches].each do |key, value|
  directory value do
    owner "www-data"
    group "www-data"
    recursive true
    action :create
  end
end

service "postgresql" do
  action :nothing
end

# Enable access for Apache to OSM data for rendering.
# As Apache is NOT run as root, it cannot run MapProxy as the render
# user. So instead we grant database access to the AWM database for
# Apache.
maps_server_user "www-data" do
  cluster "11/main"
end

maps_server_execute "GRANT #{node[:maps_server][:render_user]} TO \"www-data\"" do
  cluster "11/main"
  database node[:maps_server][:arcticwebmap][:database_name]
end

###########################
# 3. Set up MapProxy Server
###########################

package %w(libapache2-mod-wsgi)

execute "enable mod_wsgi" do
  command "a2enmod wsgi"
end

server_path = "#{mapproxy_home}/server.py"

template server_path do
  source "mapproxy/server.py.erb"
  variables({
    configuration_path: configuration_path
  })
end

# Create apache virtualhost for tile server
template "/etc/apache2/sites-available/mapproxy.conf" do
  source "apache/mapproxy.conf.erb"
  variables({
    mapproxy_path: mapproxy_home,
    server_path: server_path,
    tiles_path: "/srv/tiles/mapproxy"
  })
  notifies :reload, "service[apache2]"
end

execute "enable mapproxy apache site" do
  command "a2ensite mapproxy"
  not_if { ::File.exists?("/etc/apache2/sites-enabled/mapproxy.conf") }
  notifies :reload, "service[apache2]"
end

execute "enable mod_deflate" do
  command "a2enmod deflate"
  notifies :reload, "service[apache2]"
end
