#
# Cookbook Name:: haproxy
# Recipe:: applications
#

# disable the default and simple haproxy http routing since we are going to
# need multiple frontend/backend pairs
node.override['haproxy']['enable_default_http'] = false

def attribute(node, attrib_names)
  names = attrib_names.split('.')
  names.inject(node) do |attrib, name|
    attrib[name]
  end
end

conf = node['haproxy']

conf['applications'].each do |name,attribs|
  app_nodes =
    attribs['servers'] || search(:node, "role:#{attribs['role_name']} AND chef_environment:#{node.chef_environment}") || []

  bind_address = attribs['incoming_address'] || conf['incoming_address']
  front_maxconn = attribs['frontend_max_connections'] || conf['frontend_max_connections']
  back_maxconn = attribs['member_max_connections'] || conf['member_max_connections']

  haproxy_lb "#{name}" do
    type 'frontend'
    params({
      'maxconn' => front_maxconn,
      'bind' => "#{bind_address}:#{attribs['port']}",
      'default_backend' => "servers-#{name}"
    })
  end

  servers = app_nodes.map do |app_node|
    app_port = app_node['app_port'] || attribute(app_node, attribs['app_port_attrib'])
    "#{app_node['hostname']} #{app_node['ipaddress']}:#{app_port} weight 1 maxconn #{back_maxconn} check"
  end

  haproxy_lb "servers-#{name}" do
    type 'backend'
    servers servers
    params []
  end
end
