{% set nova = salt['openstack_utils.nova']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


nova_compute_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ nova['conf']['nova'] }}"
    - sections:
      - keystone_authtoken
    - require:
{% for pkg in nova['packages']['compute']['kvm'] %}
      - pkg: nova_compute_{{ pkg }}_install
{% endfor %}


{% set minion_ip = salt['openstack_utils.minion_ip'](grains['id']) %}
nova_compute_conf:
  ini.options_present:
    - name: {{ nova['conf']['nova'] }}
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          my_ip: {{ minion_ip }}
          vnc_enabled: True
          vncserver_listen: 0.0.0.0
          vncserver_proxyclient_address: {{ minion_ip }}
          novncproxy_base_url: "http://{{ openstack_parameters['controller_ip'] }}:6080/vnc_auto.html"
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          network_api_class: nova.network.neutronv2.api.API
          security_group_api: neutron
          linuxnet_interface_driver: nova.network.linux_net.LinuxOVSInterfaceDriver
          firewall_driver: nova.virt.firewall.NoopFirewallDriver
        keystone_authtoken: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          auth_plugin: "password"
          project_domain_id: "default"
          user_domain_id: "default"
          project_name: "service"
          username: "nova"
          password: "{{ service_users['nova']['password'] }}"
        glance:
          host: "{{ openstack_parameters['controller_ip'] }}"
        oslo_concurrency:
          lock_path: "{{ nova['files']['nova_tmp'] }}"
        neutron:
          url: "http://{{ openstack_parameters['controller_ip'] }}:9696"
          auth_strategy: keystone
          admin_auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357/v2.0"
          admin_tenant_name: service
          admin_username: neutron
          admin_password: "{{ service_users['neutron']['password'] }}"
    - require: 
      - ini: nova_compute_conf_keystone_authtoken


nova_compute_conf_virt_type:
  ini.options_present:
    - name: {{ nova['conf']['nova_compute'] }}
    - sections:
        libvirt:
          virt_type: {{ nova['libvirt_virt_type'] }}
    - require: 
      - ini: nova_compute_conf


nova_compute_running:
  service.running:
    - enable: True
    - name: {{ nova['services']['compute']['kvm']['nova'] }}
    - watch:
      - ini: nova_compute_conf
      - ini: nova_compute_conf_virt_type


nova_compute_sqlite_delete:
  file.absent:
    - name: {{ nova['files']['sqlite'] }}
    - require:
      - service: nova_compute_running


nova_compute_wait:
  cmd.run:
    - name: sleep 5
    - require:
      - service: nova_compute_running
