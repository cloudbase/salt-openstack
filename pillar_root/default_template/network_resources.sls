
neutron: 
  integration_bridge: "br-int"

  external_bridge: "<external_bridge>"

  single_nic: 
    enable: "<True/False>"
    interface: "<interface_name>"

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
    gre: 
      physnets:
        <physnet_name>:
          bridge: "<bridge_name>"
          hosts:
            "<minion_id>": "<interface_name>"
      tunnels:
        <tunnel_name>:
          tunnel_id_ranges: "<start_tunnel_id>:<end_tunnel_id>"
    vxlan: 
      physnets:
        <physnet_name>:
          bridge: "<bridge_name>"
          hosts:
            "<minion_id>": "<interface_name>"
      vxlan_group: "<multicast_group_address>"
      tunnels:
        <tunnel_name>:
          vni_range: "<start_vni>:<end_vni>"

  tunneling:
    enable: "<true/false>"
    tunnel_type: "<gre/vxlan>"
    tunnel_bridge: "br-tun"

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
        - direction: "<egress/ingress>"
          ethertype: "<IPv4/IPv6>"
          protocol: "<icmp/tcp/udp>"
          port_range_min: "<start_port>"
          port_range_max: "<end_port>"
          remote_ip_prefix: "<cidr>"
