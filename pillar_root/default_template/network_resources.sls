
neutron: 
  intergration_bridge: "br-int"

  metadata_secret: "<secret_token>"

  type_drivers: 
    flat: 
      physnets: 
        <physnet_name>: 
          bridge: "<bridge_name>"
          hosts:
            "<minion_id>": "<interface_name>"
    vlan: 
      physnets: 
        <physnet_name>: 
          bridge: "<bridge_name>"
          vlan_range: "<start_vlan>:<end_vlan>"
          hosts:
            "<minion_id>": "<interface_name>"

  networks:
    <network_name>:
      user: "<user_name>"
      tenant: "<tenant_name>"
      provider_physical_network: "<physnet_name>"
      provider_network_type: "<flat/vlan>"
      shared: "<True/False>"
      admin_state_up: "<True/False>"
      router_external: "<True/False>"
      subnets:
        <subnet_name>:
          cidr: '<cidr>'
          allocation_pools:
            - start: '<start_ip>'
              end: '<end_ip>'
          enable_dhcp: "<True/False>"
          dns_nameservers:
            - <dns_1>
            - <dns_2>

  routers:
    <router_name>:
      user: "<user_name>"
      tenant: "<tenant_name>"
      interfaces:
        - "<subnet_name_1>"
        - "<subnet_name_2>"
      gateway_network: "<network_name>"

  security_groups:
    <security_group_name>:
      user: "<user_name>"
      tenant: "<tenant_name>"
      description: "<short_description>"
      rules: 
        - protocol: "<icmp/tcp/udp>"
          direction: "<egress/ingress>"
          from-port: "<start_port>"
          to-port: "<end_port>"
          cidr: '<cidr>'
