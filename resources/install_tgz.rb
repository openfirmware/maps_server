#
# Cookbook Name:: maps_server
# Resource:: maps_server_install_tgz
#
# Copyright:: 2018–2020, James Badger, Apache-2.0 License.

default_action :install

property :archive,   :kind_of => String, :required => true
property :directory, :kind_of => String, :required => true
property :group,     :kind_of => String, :default => "root"
property :user,      :kind_of => String, :default => "root"

action :nothing do
end

action :install do
  converge_by "install #{new_resource.archive}" do
    basename = ::File.basename(new_resource.archive, ".tgz")

    script "install #{new_resource.archive}" do
      cwd ::File.dirname(new_resource.archive)
      code <<-EOH
      mkdir -p #{basename} &&
      tar -C #{new_resource.directory} -x -z -f #{new_resource.archive} &&
      cp -r #{basename} #{new_resource.directory}/.
      EOH
      group new_resource.group
      interpreter "bash"
      user new_resource.user
    end
  end
end
