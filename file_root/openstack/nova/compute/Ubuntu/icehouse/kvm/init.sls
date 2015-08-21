{% set nova = salt['openstack_utils.nova']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


nova_compute_conf:
  ini.options_present:
    - name: {{ nova['conf']['nova'] }}
    - sections:
        database:
          connection: "mysql://{{ nova['database']['username'] }}:{{ nova['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ nova['database']['db_name'] }}"
        DEFAULT:
          auth_strategy: keystone
          my_ip: "{{ salt['openstack_utils.minion_ip'](grains['id']) }}"
          vnc_enabled: True
          vncserver_listen: "0.0.0.0"
          vncserver_proxyclient_address: "{{ salt['openstack_utils.minion_ip'](grains['id']) }}"
          novncproxy_base_url: "http://{{ openstack_parameters['controller_ip'] }}:6080/vnc_auto.html"
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          network_api_class: nova.network.neutronv2.api.API
          linuxnet_interface_driver: nova.network.linux_net.LinuxOVSInterfaceDriver
          firewall_driver: nova.virt.firewall.NoopFirewallDriver
          security_group_api: neutron
          neutron_url: "http://{{ openstack_parameters['controller_ip'] }}:9696"
          neutron_auth_strategy: keystone
          neutron_admin_tenant_name: service
          neutron_admin_username: neutron
          neutron_admin_password: "{{ service_users['neutron']['password'] }}"
          neutron_admin_auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357/v2.0"
          vif_plugging_is_fatal: False
          vif_plugging_timeout: 10
        keystone_authtoken:
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_host: "{{ openstack_parameters['controller_ip'] }}"
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: nova
          admin_password: "{{ service_users['nova']['password'] }}"
        glance:
          host: "{{ openstack_parameters['controller_ip'] }}"
    - require:
{% for pkg in nova['packages']['compute']['kvm'] %}
      - pkg: nova_compute_{{ pkg }}_install
{% endfor %}


nova_compute_conf_virt_type:
  ini.options_present:
    - name: {{ nova['conf']['nova_compute'] }}
    - sections:
        libvirt:
          virt_type: {{ nova['libvirt_virt_type'] }}
          cpu_mode: none
    - require:
      - ini: nova_compute_conf


{% for service in nova['services']['compute']['kvm'] %}
nova_compute_{{ service }}_running:
  service.running:
    - enable: True
    - name: {{ nova['services']['compute']['kvm'][service] }}
    - watch:
      - ini: nova_compute_conf
      - ini: nova_compute_conf_virt_type
{% endfor %}


nova_compute_sqlite_delete:
  file.absent:
    - name: {{ nova['files']['sqlite'] }}
    - require:
{% for service in nova['services']['compute']['kvm'] %}
      - service: nova_compute_{{ service }}_running
{% endfor %}


nova_compute_wait:
  cmd.run:
    - name: sleep 5
    - require:
{% for service in nova['services']['compute']['kvm'] %}
      - service: nova_compute_{{ service }}_running
{% endfor %}


