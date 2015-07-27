{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


neutron_compute_sysctl_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['sysctl'] }}"
    - sections: 
        DEFAULT_IMPLICIT: 
          net.ipv4.conf.all.rp_filter: 0
          net.ipv4.conf.default.rp_filter: 0


neutron_compute_sysctl_enable:
  cmd.run:
    - name: "sysctl -p"
    - require:
      - ini: neutron_compute_sysctl_conf


neutron_compute_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections:
      - keystone_authtoken
    - require:
{% for pkg in neutron['packages']['compute']['kvm'] %}
      - pkg: neutron_compute_{{ pkg }}_install
{% endfor %}


neutron_compute_conf:
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
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          auth_plugin: "password"
          project_domain_id: "default"
          user_domain_id: "default"
          project_name: "service"
          username: "neutron"
          password: "{{ service_users['neutron']['password'] }}"
    - require: 
      - ini: neutron_compute_conf_keystone_authtoken


neutron_compute_ml2_conf:
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
{% if salt['openstack_utils.boolean_value'](neutron['tunneling']['enable']) %} 
        agent:
          tunnel_types: "{{ ','.join(neutron['tunneling']['types']) }}"
{% endif %}
    - require:
      - ini: neutron_compute_conf


neutron_compute_ml2_symlink:
  file.symlink:
    - name: {{ neutron['conf']['ml2_symlink'] }}
    - target: {{ neutron['conf']['ml2'] }}
    - require:
      - ini: neutron_compute_ml2_conf


neutron_compute_ovs_fix_cp:
  file.copy:
    - name: {{ neutron['conf']['ovs_systemd'] }}.orig
    - source: {{ neutron['conf']['ovs_systemd'] }}
    - unless: ls {{ neutron['conf']['ovs_systemd'] }}.orig
    - require:
{% for pkg in neutron['packages']['compute']['kvm'] %}
      - pkg: neutron_compute_{{ pkg }}_install
{% endfor %}


neutron_compute_ovs_fix_sed:
  cmd.run:
    - name: sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' {{ neutron['conf']['ovs_systemd'] }}
    - require:
      - file: neutron_compute_ovs_fix_cp


{% for service in neutron['services']['compute']['kvm'] %}
neutron_compute_{{ service }}_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['compute']['kvm'][service] }}"
    - watch:
      - ini: neutron_compute_conf
      - ini: neutron_compute_ml2_conf
{% endfor %}


neutron_compute_wait:
  cmd.run:
    - name: "sleep 5"
    - require:
{% for service in neutron['services']['compute']['kvm'] %}
      - service: neutron_compute_{{ service }}_running
{% endfor %}
