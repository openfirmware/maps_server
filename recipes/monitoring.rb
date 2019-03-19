#
# Cookbook:: maps_server
# Recipe:: monitoring
#
# Copyright:: 2018–2019, James Badger, Apache-2.0 License.
# With code based on https://github.com/openstreetmap/chef/tree/master/cookbooks/munin

# Install plugins to /usr/local/share/munin/plugins/
plugins_dir = "/usr/local/share/munin/plugins"

cookbook_file "#{plugins_dir}/planet_age" do
  source 'munin-plugins/planet_age'
  mode '0755'
end

# Enable plugins by creating links in /etc/munin/plugins/
# Running this a second time (after the `base_monitoring` recipe) will
# cause new plugins to be recognized.
execute 'enable default munin node plugins' do
  command 'munin-node-configure --suggest --shell | sh'
end

link "/etc/munin/plugins/planet_age" do
  to "#{plugins_dir}/planet_age"
end

mod_tile_plugins = %w(mod_tile_fresh mod_tile_response renderd_processed renderd_queue_time renderd_zoom_time mod_tile_latency mod_tile_zoom renderd_queue renderd_zoom replication_delay)

mod_tile_plugins.each do |plugin|
  link "/etc/munin/plugins/#{plugin}" do
    to "/opt/mod_tile/munin/#{plugin}"
  end
end

service 'munin-node' do
  action :restart
end

service 'rrdcached' do
  action :restart
end

service 'apache2' do
  action :restart
end
