{% from "cluster/physical_networks.jinja" import mappings with context %}
{% from "cluster/physical_networks.jinja" import vlan_networks with context %}
{% from "cluster/physical_networks.jinja" import flat_networks with context %}
{% from "cluster/physical_networks.jinja" import type_drivers with context %}
{% from "cluster/physical_networks.jinja" import tenant_network_types with context %}
{% from "cluster/physical_networks.jinja" import gre_tunnel_id_ranges with context %}
{% from "cluster/physical_networks.jinja" import vxlan_tunnels_vni_ranges with context %}

neutron_ml2_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_ml2') }}"

neutron_ml2_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron_ml2') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require:
      - ini: neutron_ml2_conf
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron_ml2') }}"
    - sections:
        ml2:
          type_drivers: "{{ ','.join(type_drivers) }}"
          tenant_network_types: "{{ ','.join(tenant_network_types) }}"
          mechanism_drivers: openvswitch
{% if 'flat' in type_drivers %}
        ml2_type_flat:
          flat_networks: "{{ ','.join(flat_networks) }}"
{% endif %}
{% if 'vlan' in type_drivers %}
        ml2_type_vlan: 
          network_vlan_ranges: "{{ ','.join(vlan_networks) }}"
{% endif %}
{% if salt['pillar.get']('neutron:tunneling:enable').lower() == 'true' %} 
  {% if 'gre' in type_drivers and salt['pillar.get']('neutron:tunneling:tunnel_type').lower() == 'gre' %}
        ml2_type_gre: 
          tunnel_id_ranges: "{{ ','.join(gre_tunnel_id_ranges) }}"
  {% endif %}
  {% if 'vxlan' in type_drivers and salt['pillar.get']('neutron:tunneling:tunnel_type').lower() == 'vxlan' %}
        ml2_type_vxlan:
          vxlan_group: "{{ salt['pillar.get']('neutron:type_drivers:vxlan:vxlan_group') }}"
          vni_ranges: "{{ ','.join(vxlan_tunnels_vni_ranges) }}"
  {% endif %}
{% endif %}
        ovs:
          integration_bridge: "{{ salt['pillar.get']('neutron:integration_bridge', default='br-int') }}"
{% if mappings != [] %}
          bridge_mappings: "{{  ','.join(mappings)  }}"
{% endif %}
          enable_tunneling: {{ salt['pillar.get']('neutron:tunneling:enable').lower().title() }}
{% if salt['pillar.get']('neutron:tunneling:enable').lower() == 'true' %}
          polling_interval: 2
          local_ip: "{{ salt['pillar.get']('hosts:%s' % grains['id']) }}"
          l2_population: False
          arp_responder: False
          enable_distributed_routing: False
          tunnel_bridge: "{{ salt['pillar.get']('neutron:tunneling:tunnel_bridge') }}"
          tunnel_type: "{{ salt['pillar.get']('neutron:tunneling:tunnel_type') }}"
        agent:
          tunnel_types: "{{ salt['pillar.get']('neutron:tunneling:tunnel_type') }}"
{% endif %}
        securitygroup:
          firewall_driver: neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
{% if pillar['cluster_type'] == 'juno' %}
          enable_ipset: True
{% endif %}
          enable_security_group: True
    - require:
      - pkg: neutron_ml2_install
