# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'ridley'

# assume 'dev' environment for Ridley searches unless overridden
chef_environment = ENV['CHEF_ENVIRONMENT'] || 'dev'

# roles for proxied nodes
dicer_role = 'dicer_main'
geoserver_role = 'map_server2'

# these ports can be anything; these are the convention we are using
# in the dev.rb environment file
haproxy_ports = {
  'ogc' => {
    'dicer' => 8888,
    'geoserver' => 8889
  }
}

# while sort of gross to depend on another library's config, we are heavily
# leveraging Berkshelf and we need these same Chef config values for Ridley
def load_berks_config()
  JSON.parse(IO.read("#{Dir.home}/.berkshelf/config.json"))
end

# initialize ridley using the chef config from berkshelf
chef_config = load_berks_config()['chef']
ridley = Ridley.new(
  server_url: chef_config['chef_server_url'],
  client_name: chef_config['node_name'],
  client_key: chef_config['client_key']
)

# find nodes in role in target environment and return an array of mashes of
# chef attributes; this allows accessing node attributes in the familiar chef
# syntax
def find_nodes(ridley, env, role_name)
  ridley.search(
    :node, "chef_environment:#{env} AND role:#{role_name}"
  ).map {
    |node| node.chef_attributes()
  }
end

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu-12.04-1.0.0"
  config.vm.box_url = "http://ausvf-nexus01v.na.drillinginfo.com/filerepo/vagrant_boxes/ubuntu-12.04/ubuntu-12.04-1.0.0.box"

  config.vm.network :private_network, ip: "192.168.2.10"

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.auto_detect = true
  end

  # find dependencies for the target environment
  dicers = find_nodes(ridley, chef_environment, dicer_role)
  geoservers = find_nodes(ridley, chef_environment, geoserver_role)

  config.omnibus.chef_version = ENV['CHEF_VERSION'] || :latest

  config.vm.provision :chef_solo do |chef|
    chef.log_level = :debug

    chef.json = {
      'haproxy' => {
        'frontend_max_connections' => 10000,
        'member_max_connections' => 200,
        'applications' => {
          'ogc-dicer' => {
            'port' => haproxy_ports['ogc']['dicer'],
            'servers' => dicers.map {|node| {
              'hostname' => node['hostname'],
              'ipaddress' => node['ipaddress'],
              'app_port' => node['dicer']['http_port']
            }}
          },
          'ogc-geoserver' => {
            'port' => haproxy_ports['ogc']['geoserver'],
            'servers' => geoservers.map {|node| {
              'hostname' => node['hostname'],
              'ipaddress' => node['ipaddress'],
              'app_port' => node['tomcat']['port']
            }}
          }
        }
      }
    }

    chef.run_list = [
      "recipe[apt]",
      "recipe[haproxy::applications]",
      "recipe[haproxy::default]"
    ]
  end
end
