{% from "cluster/resources.jinja" import get_candidate with context %}

neutron_server_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_server') }}"

python_neutronclient_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_pythonclient') }}"

{% if grains['os'] == 'CentOS' and grains['osrelease_info'][0] == 7 %}
which_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:which') }}"
{% endif %}

neutron_conf_file:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require: 
      - ini: neutron_conf_file
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron') }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
{% if pillar['cluster_type'] == 'icehouse' and salt['pillar.get']('queue_engine') == 'rabbit' %}
          rpc_backend: "neutron.openstack.common.rpc.impl_kombu"
{% else %}
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
{% endif %}
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          verbose: True
          notify_nova_on_port_status_changes: True
          notify_nova_on_port_data_changes: True
          nova_url: "http://{{ get_candidate('nova') }}:8774/v2"
{% if pillar['cluster_type'] == 'juno' %}
          nova_region_name: RegionOne
{% endif %}
          nova_admin_username: nova
          nova_admin_tenant_id: service
          nova_admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:nova:password') }}"
          nova_admin_auth_url: "http://{{ get_candidate('keystone') }}:35357/v2.0"
        keystone_authtoken: 
{% if pillar['cluster_type'] == 'juno' %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          identity_uri: http://{{ get_candidate('keystone') }}:35357
{% else %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_protocol: http
          auth_port: 35357
{% endif %}
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:neutron:username') }}:{{ salt['pillar.get']('databases:neutron:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:neutron:db_name') }}"
    - require: 
      - pkg: neutron_server_install
      - pkg: python_neutronclient_install

neutron_networking_nova_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:nova') }}"
    - user: nova
    - group: nova
    - mode: 644
    - require:
      - ini: neutron_networking_nova_conf
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:nova') }}"
    - sections: 
        DEFAULT: 
          network_api_class: "nova.network.neutronv2.api.API"
          security_group_api: "neutron"
          linuxnet_interface_driver: "nova.network.linux_net.LinuxOVSInterfaceDriver"
          firewall_driver: "nova.virt.firewall.NoopFirewallDriver"
          vif_plugging_is_fatal: False
          vif_plugging_timeout: 0
{% if pillar['cluster_type'] == 'juno' %}
        neutron:
          url: http://{{ get_candidate('neutron') }}:9696
          auth_strategy: keystone
          admin_auth_url: http://{{ get_candidate('keystone') }}:35357/v2.0
          admin_tenant_name: service
          admin_username: neutron
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
          service_metadata_proxy: True
          metadata_proxy_shared_secret: "{{ salt['pillar.get']('neutron:metadata_secret') }}"
{% else %}
          neutron_url: "http://{{ get_candidate('neutron') }}:9696"
          neutron_auth_strategy: "keystone"
          neutron_admin_tenant_name: "service"
          neutron_admin_username: "neutron"
          neutron_admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
          neutron_admin_auth_url: "http://{{ get_candidate('keystone') }}:35357/v2.0"
          service_neutron_metadata_proxy: "True"
          neutron_metadata_proxy_shared_secret: "{{ salt['pillar.get']('neutron:metadata_secret') }}"
{% endif %}
    - require: 
      - pkg: neutron_server_install
      - pkg: python_neutronclient_install

{% if pillar['cluster_type'] == 'juno' and grains['os'] == 'CentOS' %}
enable_neutron_plugin_neutron: 
  file: 
    - symlink
    - force: true
    - name: "{{ salt['pillar.get']('conf_files:neutron_plugin_ini') }}"
    - target: "{{ salt['pillar.get']('conf_files:neutron_ml2') }}"
    - require: 
      - file: neutron_conf_file
{% endif %}

nova_api_restart:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_api') }}"
    - watch:
      - file: neutron_networking_nova_conf
      - ini: neutron_networking_nova_conf

nova_scheduler_restart:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_scheduler') }}"
    - watch:
      - file: neutron_networking_nova_conf
      - ini: neutron_networking_nova_conf

nova_conductor_restart:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_conductor') }}"
    - watch:
      - file: neutron_networking_nova_conf
      - ini: neutron_networking_nova_conf

{% if pillar['cluster_type'] == 'juno' %}
neutron_db_sync:
  cmd:
    - run
    - name: su -s /bin/sh -c "neutron-db-manage --config-file {{ salt['pillar.get']('conf_files:neutron') }} --config-file {{ salt['pillar.get']('conf_files:neutron_ml2') }} upgrade juno" neutron
    - require:
      - pkg: neutron_server_install
      - pkg: python_neutronclient_install
{% if grains['os'] == 'CentOS' %}
      - file: enable_neutron_plugin_neutron
{% endif %}
    - watch:
      - file: neutron_conf_file
      - ini: neutron_conf_file
      - file: neutron_ml2_conf
      - ini: neutron_ml2_conf
{% endif %}

neutron_server_service_running:
  service: 
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:neutron_server') }}"
    - require: 
      - pkg: neutron_server_install
    - watch: 
      - file: neutron_conf_file
      - ini: neutron_conf_file
      - file: neutron_ml2_conf
      - ini: neutron_ml2_conf
{% if pillar['cluster_type'] == 'juno' %}
      - cmd: neutron_db_sync
{% endif %}

neutron_server_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: neutron_server_service_running
