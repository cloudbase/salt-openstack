{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


neutron_network_ipv4_forwarding_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['sysctl'] }}"
    - sections: 
        DEFAULT_IMPLICIT: 
          net.ipv4.conf.all.rp_filter: 0
          net.ipv4.ip_forward: 1
          net.ipv4.conf.default.rp_filter: 0


neutron_network_ipv4_forwarding_enable:
  cmd.run:
    - name: "sysctl -p"
    - require:
      - ini: neutron_network_ipv4_forwarding_conf


neutron_network_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections:
        keystone_authtoken:
          - auth_host
          - auth_port
          - auth_protocol
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
        keystone_authtoken: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000/v2.0"
          identity_uri: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ service_users['neutron']['password'] }}"
    - require: 
      - ini: neutron_network_conf_keystone_authtoken


neutron_network_ml2_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['ml2'] }}"
    - sections:
        ml2:
          type_drivers: "{{ ','.join(neutron['ml2_type_drivers']) }}"
          tenant_network_types: "{{ ','.join(neutron['tenant_network_types']) }}"
          mechanism_drivers: openvswitch
{% if 'flat' in neutron['ml2_type_drivers'] %}
        ml2_type_flat:
          flat_networks: "{{ ','.join(neutron['flat_networks']) }}"
{% endif %}
{% if 'vlan' in neutron['ml2_type_drivers'] %}
        ml2_type_vlan:
          network_vlan_ranges: "{{ ','.join(neutron['vlan_networks']) }}"
{% endif %}
{% if 'gre' in neutron['ml2_type_drivers'] %}
        ml2_type_gre:
          tunnel_id_ranges: "{{ ','.join(neutron['gre_tunnel_id_ranges']) }}"
{% endif %}
{% if 'vxlan' in neutron['ml2_type_drivers'] %}
        ml2_type_vxlan:
          vxlan_group: "{{ neutron['vxlan_group'] }}"
          vni_ranges: "{{ ','.join(neutron['vxlan_tunnels_vni_ranges']) }}"
{% endif %}
        securitygroup:
          enable_security_group: True
          enable_ipset: True
          firewall_driver: "neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver"
        ovs:
          integration_bridge: {{ neutron['integration_bridge'] }}
          local_ip: {{ salt['openstack_utils.minion_ip'](grains['id']) }}
{% if neutron['bridge_mappings'] %}
          bridge_mappings: "{{ ','.join(neutron['bridge_mappings']) }}"
{% endif %}
{% if salt['openstack_utils.boolean_value'](neutron['tunneling']['enable']) %} 
          tunnel_bridge: "{{ neutron['tunneling']['bridge'] }}"
          enable_tunneling: True
        agent:
          tunnel_types: "{{ ','.join(neutron['tunneling']['types']) }}"
{% else %}
          enable_tunneling: False
{% endif %}
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ml2_symlink:
  file.symlink:
    - name: {{ neutron['conf']['ml2_symlink'] }}
    - target: {{ neutron['conf']['ml2'] }}
    - require:
      - ini: neutron_network_ml2_conf


neutron_network_l3_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['l3_agent'] }}"
    - sections: 
        DEFAULT: 
          interface_driver: neutron.agent.linux.interface.OVSInterfaceDriver
          external_network_bridge: {{ neutron['external_bridge'] }}
          router_delete_namespaces: True
          use_namespaces: True
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_dhcp_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['dhcp_agent'] }}"
    - sections: 
        DEFAULT: 
          interface_driver: neutron.agent.linux.interface.OVSInterfaceDriver
          dhcp_driver: neutron.agent.linux.dhcp.Dnsmasq
          use_namespaces: True
          dhcp_delete_namespaces: True
          dnsmasq_config_file: {{ neutron['conf']['dnsmasq_config_file'] }}
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_dnsmasq_conf:
  ini.options_present:
    - name: {{ neutron['conf']['dnsmasq_config_file'] }}
    - sections:
        DEFAULT_IMPLICIT:
          dhcp-option-force: 26,1454
    - require:
      - ini: neutron_network_dhcp_agent_conf


neutron_network_metadata_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['metadata_agent'] }}"
    - sections: 
        DEFAULT: 
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:5000/v2.0"
          auth_region: RegionOne
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ service_users['neutron']['password'] }}"
          nova_metadata_ip: {{ openstack_parameters['controller_ip'] }}
          metadata_proxy_shared_secret: {{ neutron['metadata_secret'] }}
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ovs_fix_cp:
  file.copy:
    - name: {{ neutron['conf']['ovs_systemd'] }}.orig
    - source: {{ neutron['conf']['ovs_systemd'] }}
    - unless: ls {{ neutron['conf']['ovs_systemd'] }}.orig
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ovs_fix_sed:
  cmd.run:
    - name: sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' {{ neutron['conf']['ovs_systemd'] }}
    - require:
      - file: neutron_network_ovs_fix_cp


neutron_network_openvswitch_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['ovs'] }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_openvswitch_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['ovs_agent'] }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ovs_cleanup_running:
  service.enabled:
    - name: "{{ neutron['services']['network']['ovs_agent'] }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_l3_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['l3_agent'] }}"
    - watch: 
      - ini: neutron_network_l3_agent_conf


neutron_network_dhcp_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['dhcp_agent'] }}"
    - watch: 
      - ini: neutron_network_dhcp_agent_conf


neutron_network_metadata_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['metadata_agent'] }}"
    - watch: 
      - ini: neutron_network_metadata_agent_conf


neutron_network_wait:
  cmd.run:
    - name: "sleep 5"
    - require:
      - service: neutron_network_openvswitch_running
      - service: neutron_network_openvswitch_agent_running
      - service: neutron_network_l3_agent_running
      - service: neutron_network_dhcp_agent_running
      - service: neutron_network_metadata_agent_running
