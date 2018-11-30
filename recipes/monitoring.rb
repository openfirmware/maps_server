#
# Cookbook:: maps_server
# Recipe:: monitoring
#
# Copyright:: 2018, James Badger, Apache-2.0 License.
# With code based on https://github.com/openstreetmap/chef/tree/master/cookbooks/munin

apt_update

# Install Munin Server
package 'munin'
package 'apache2'
package 'rrdcached'
package 'libcgi-fast-perl'
package 'libapache2-mod-fcgid'

template '/etc/default/rrdcached' do
  source 'rrdcached.erb'
  owner 'root'
  group 'root'
  mode '644'
end

directory "/var/lib/munin/rrdcached" do
  owner "munin"
  group "munin"
  mode 0o755
end

service "rrdcached" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/default/rrdcached]"
end

expiry_time = 14 * 86400

template "/etc/munin/munin.conf" do
  source "munin.conf.erb"
  owner "root"
  group "root"
  mode 0o644
  variables :expiry_time => expiry_time
end

template '/etc/apache2/sites-available/munin.conf' do
  source 'apache-munin.conf.erb'
end

%w(fcgid rewrite headers).each do |apache_module|
  execute "enable apache module #{apache_module}" do
    command "a2enmod #{apache_module}"
  end
end

execute "enable munin site" do
  command "a2ensite munin"
end

service "apache2" do
  action :restart
end

# Install Munin Client
package 'munin-node'
package 'ruby'
package 'libdbd-pg-perl'

# Install plugins to /usr/local/share/munin/plugins/
plugins_dir = "/usr/local/share/munin/plugins"

directory plugins_dir do
  recursive true
  action :create
end

cookbook_file "#{plugins_dir}/planet_age" do
  source 'munin-plugins/planet_age'
  mode '0755'
end

# Enable plugins by creating links in /etc/munin/plugins/

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
