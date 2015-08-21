{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


neutron_controller_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections:
      - keystone_authtoken
    - require:
{% for pkg in neutron['packages']['controller'] %}
      - pkg: neutron_controller_{{ pkg }}_install
{% endfor %}


neutron_controller_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections: 
        database: 
          connection: "mysql://{{ neutron['database']['username'] }}:{{ neutron['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ neutron['database']['db_name'] }}"
        DEFAULT: 
          auth_strategy: keystone
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          notify_nova_on_port_status_changes: True
          notify_nova_on_port_data_changes: True
          nova_url: "http://{{ openstack_parameters['controller_ip'] }}:8774/v2"
        keystone_authtoken: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          auth_plugin: "password"
          project_domain_id: "default"
          user_domain_id: "default"
          project_name: "service"
          username: "neutron"
          password: "{{ service_users['neutron']['password'] }}"
        nova:
          auth_url: http://{{ openstack_parameters['controller_ip'] }}:35357
          auth_plugin: password
          project_domain_id: default
          user_domain_id: default
          region_name: RegionOne
          project_name: service
          username: nova
          password: "{{ service_users['nova']['password'] }}"
    - require:
      - ini: neutron_controller_conf_keystone_authtoken


neutron_controller_ml2_conf:
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
    - require:
      - ini: neutron_controller_conf


neutron_controller_ml2_symlink:
  file.symlink:
    - name: {{ neutron['conf']['ml2_symlink'] }}
    - target: {{ neutron['conf']['ml2'] }}
    - require:
      - ini: neutron_controller_ml2_conf


neutron_db_sync:
  cmd.run:
    - name: "su -s /bin/sh -c 'neutron-db-manage --config-file {{ neutron['conf']['neutron'] }} --config-file {{ neutron['conf']['ml2'] }} upgrade head' neutron"


neutron_controller_server_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['controller']['neutron_server'] }}"
    - watch:
      - ini: neutron_controller_conf
      - ini: neutron_controller_ml2_conf


neutron_controller_wait:
  cmd.run:
    - name: sleep 5
    - require:
      - service: neutron_controller_server_running
