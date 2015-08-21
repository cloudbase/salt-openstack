neutron:
  integration_bridge: "br-int"

  external_bridge: "br-ex"

  single_nic:
    enable: True
    interface: "eth0"
    set_up_script: "/root/br-proxy.sh"

  type_drivers:
    flat:
      physnets:
        physnet0:
          bridge: "br-ex"
          hosts:
            "ubuntu.openstack": ""
    vlan:
      physnets:
        physnet1:
          bridge: "br-data"
          vlan_range: "100:200"
          hosts:
            "ubuntu.openstack": ""

  tunneling:
    enable: False
    types:
      - vxlan
    bridge: "br-tun"

  networks:
    public:
      user: "admin"
      tenant: "admin"
      shared: True
      admin_state_up: True
      router_external: True
      provider_physical_network: "physnet0"
      provider_network_type: "flat"
      subnets:
        public_subnet:
          cidr: '192.168.137.0/24'
          allocation_pools:
            - start: '192.168.137.80'
              end: '192.168.137.90'
          enable_dhcp: False
          gateway_ip: "192.168.137.2"
    private:
      user: "admin"
      tenant: "admin"
      admin_state_up: True
      subnets:
        private_subnet:
          cidr: '10.0.1.0/24'
          dns_nameservers:
            - 8.8.8.8

  routers:
    router1:
      user: "admin"
      tenant: "admin"
      interfaces:
        - "private_subnet"
      gateway_network: "public"

  security_groups:
    default:
      user: admin
      tenant: admin
      description: 'default'
      rules: # Allow all traffic on the default security group
        - direction: "ingress"
          ethertype: "IPv4"
          protocol: "TCP"
          port_range_min: "1"
          port_range_max: "65535"
          remote_ip_prefix: "0.0.0.0/0"
        - direction: "ingress"
          ethertype: "IPv4"
          protocol: "UDP"
          port_range_min: "1"
          port_range_max: "65535"
          remote_ip_prefix: "0.0.0.0/0"
        - direction: ingress
          protocol: ICMP
          remote_ip_prefix: '0.0.0.0/0'
