#
# Cookbook:: maps_server
# Recipe:: mapproxy
#
# Copyright:: 2019, James Badger, Apache-2.0 License.

#####################
# 1. Install Packages
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