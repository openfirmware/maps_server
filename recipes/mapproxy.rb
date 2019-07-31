#
# Cookbook:: maps_server
# Recipe:: mapproxy
#
# Copyright:: 2019, James Badger, Apache-2.0 License.

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
  owner node[:maps_server][:render_user]
  recursive true
  action :create
end

# Checkout from master as the latest release is from Nov 2017 and there
# are necessary fixes for token problems added to the master branch.
# If a new MapProxy Python package is released, this block can be 
# changed to a pip install resource instead.
git "#{mapproxy_home}/src" do
  repository "https://github.com/mapproxy/mapproxy"
  reference "master"
end

execute "install mapproxy from source" do
  command "make install"
  cwd "#{mapproxy_home}/src"
end

configuration_path = "#{mapproxy_home}/mapproxy.yaml"

# template configuration_path do
#   source "mapproxy/config.yaml.erb"
#   mode "755"
# end

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
    user: node[:maps_server][:render_user],
    group: node[:maps_server][:render_user]
  })
end

execute "enable mapproxy apache site" do
  command "a2ensite mapproxy"
  not_if { ::File.exists?("/etc/apache2/sites-enabled/mapproxy.conf") }
  notifies :reload, "service[apache2]"
end
