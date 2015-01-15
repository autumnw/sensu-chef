#
# Cookbook Name:: sensu
# Recipe:: _windows
#
# Copyright 2014, Sonian Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Chef::Recipe.send(:include, Windows::Helper)

user "sensu" do
  password Sensu::Helpers.random_password
  not_if {
    user = Chef::Util::Windows::NetUser.new("sensu")
    !!user.get_info rescue false
  }
end

group "sensu" do
  members "sensu"
  action :manage
end

if win_version.windows_server_2012? || win_version.windows_server_2012_r2?
  windows_feature "NetFx3ServerFeatures" do
    source node.sensu.windows.dism_source
  end
end

windows_feature "NetFx3" do
  source node.sensu.windows.dism_source
end

windows_package "Sensu" do
  source "#{node.sensu.msi_repo_url}/sensu-#{node.sensu.version}.msi"
  options node.sensu.windows.package_options
  version node.sensu.version.gsub("-", ".")
  notifies :create, "ruby_block[sensu_service_trigger]", :immediately
end


template 'C:\opt\sensu\bin\sensu-client.xml' do
  source "sensu.xml.erb"
  variables :service => "sensu-client", :name => "Sensu Client"
  notifies :create, "ruby_block[sensu_service_trigger]", :immediately
end

## Temp fix soulution for error
template 'C:\opt\sensu\embedded\lib\ruby\gems\2.0.0\gems\sensu-em-2.4.0-x86-mingw32\lib\em\connection.rb' do
  source "connection.rb.erb"
  action :create
end

## Install sensu-plugin which was missed from msi package
local_dir = 'c:\chef\cache\sensu-plugin'
directory "#{local_dir}" do
  action :create
end

['json-1.8.2.gem', 'mixlib-cli-1.5.0.gem', 'sensu-plugin-1.1.0.gem'].each do |gem|
  remote_file "#{local_dir}\#{gem}" do
    source "#{node.sensu.msi_repo_url}/sensu-plugin/#{gem}"
    action :create
  end
end

gem_package 'sensu-plugin' do
  gem_binary('c:\opt\sensu\embedded\bin\gem')
  source "#{local_dir}\sensu-plugin-1.1.0.gem"
  action :install
end

execute "sensu-client.exe install" do
  cwd 'C:\opt\sensu\bin'
  not_if {
    ::Win32::Service.exists?("sensu-client")
  }
end
