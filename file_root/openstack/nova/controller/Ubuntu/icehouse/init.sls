{% set nova = salt['openstack_utils.nova']() %}
{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


nova_controller_conf:
  ini.options_present:
    - name: "{{ nova['conf']['nova'] }}"
    - sections:
        database:
          connection: "mysql://{{ nova['database']['username'] }}:{{ nova['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ nova['database']['db_name'] }}"
        DEFAULT:
          auth_strategy: "keystone"
          my_ip: "{{ openstack_parameters['controller_ip'] }}"
          vncserver_listen: "{{ openstack_parameters['controller_ip'] }}"
          vncserver_proxyclient_address: "{{ openstack_parameters['controller_ip'] }}"
          cpu_allocation_ratio: {{ salt['pillar.get']('nova:cpu_allocation_ratio') }}
          ram_allocation_ratio: {{ salt['pillar.get']('nova:ram_allocation_ratio') }}
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          service_neutron_metadata_proxy: True
          neutron_metadata_proxy_shared_secret: {{ neutron['metadata_secret'] }}
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
{% for pkg in nova['packages']['controller'] %}
      - pkg: nova_controller_{{ pkg }}_install
{% endfor %}


nova_db_sync:
  cmd.run:
    - name: "su -s /bin/sh -c 'nova-manage db sync' nova"
    - require: 
      - ini: nova_controller_conf


nova_controller_sqlite_delete:
  file.absent:
    - name: {{ nova['files']['sqlite'] }}
    - require:
      - cmd: nova_db_sync


{% for service in nova['services']['controller'] %}
nova_controller_{{ service }}_running:
  service.running:
    - enable: True
    - name: "{{ nova['services']['controller'][service] }}"
    - require:
      - cmd: nova_db_sync
    - watch:
      - ini: nova_controller_conf
{% endfor %}


nova_controller_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
{% for service in nova['services']['controller'] %}
      - service: nova_controller_{{ service }}_running
{% endfor %}
