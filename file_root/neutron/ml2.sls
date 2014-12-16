{% from "cluster/physical_networks.jinja" import mappings with context %}
{% from "cluster/physical_networks.jinja" import vlan_networks with context %}
{% from "cluster/physical_networks.jinja" import flat_networks with context %}

neutron_ml2_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_ml2', default='neutron-plugin-ml2') }}"

neutron_ml2_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron_ml2', default='/etc/neutron/plugins/ml2/ml2_conf.ini') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require:
      - ini: neutron_ml2_conf
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron_ml2', default='/etc/neutron/plugins/ml2/ml2_conf.ini') }}"
    - sections:
        ml2:
          type_drivers: "{{ ','.join(salt['pillar.get']('neutron:type_drivers')) }}"
          tenant_network_types: "{{ ','.join(salt['pillar.get']('neutron:type_drivers')) }}"
          mechanism_drivers: openvswitch
{% if 'flat' in salt['pillar.get']('neutron:type_drivers') %}
        ml2_type_flat:
          flat_networks: "{{ ','.join(flat_networks) }}"
{% endif %}
{% if 'vlan' in salt['pillar.get']('neutron:type_drivers') %}
        ml2_type_vlan: 
          network_vlan_ranges: "{{ ','.join(vlan_networks) }}"
{% endif %}
{% if 'gre' in salt['pillar.get']('neutron:type_drivers') %}
        ml2_type_gre: 
          tunnel_id_ranges: "{{ salt['pillar.get']('neutron:type_drivers:gre:tunnel_start') }}:{{ salt['pillar.get']('neutron:type_drivers:gre:tunnel_end') }}"
{% endif %}
{% if 'vxlan' in salt['pillar.get']('neutron:type_drivers') %}
        ml2_type_vxlan:
          vni_ranges: "{{ salt['pillar.get']('neutron:type_drivers:gre:tunnel_start') }}:{{ salt['pillar.get']('neutron:type_drivers:gre:tunnel_end') }}"
{% endif %}
        ovs:
{% if 'flat' in salt['pillar.get']('neutron:type_drivers') or 'vlan' in salt['pillar.get']('neutron:type_drivers') %}
          bridge_mappings: "{{  ','.join(mappings)  }}"
{% endif %}
{% if 'gre' in salt['pillar.get']('neutron:type_drivers') %}
          tunnel_type: gre
          enable_tunneling: True
          local_ip: "{{ salt['pillar.get']('hosts:%s' % grains['id']) }}"
{% endif %}
{% if 'vxlan' in salt['pillar.get']('neutron:type_drivers') %}
          tunnel_type: vxlan
          enable_tunneling: True
          local_ip: "{{ salt['pillar.get']('hosts:%s' % grains['id']) }}"
{% endif %}
        securitygroup:
          firewall_driver: neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
          enable_security_group: True
    - require:
      - pkg: neutron_ml2_install
