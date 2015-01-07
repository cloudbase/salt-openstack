{% from "cluster/resources.jinja" import get_candidate with context %}

nova_api_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_api', default='nova-api') }}"

nova_cert_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_cert', default='nova-cert') }}"

nova_conductor_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_conductor', default='nova-conductor') }}"

nova_consoleauth_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_consoleauth', default='nova-consoleauth') }}"

nova_novncproxy_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_novncproxy', default='nova-novncproxy') }}"

nova_scheduler_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_scheduler', default='nova-scheduler') }}"

python_novaclient_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_pythonclient', default='python-novaclient') }}"

nova_ajax_console_proxy_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_ajax_console_proxy', default='nova-ajax-console-proxy') }}"

novnc_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:novnc', default='novnc') }}"

nova_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:nova', default='/etc/nova/nova.conf') }}"
    - user: nova
    - group: nova
    - mode: 644
    - require:
      - ini: nova_conf
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:nova', default='/etc/nova/nova.conf') }}"
    - sections: 
        DEFAULT: 
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
          my_ip: "{{ get_candidate('nova') }}"
          vncserver_listen: "{{ get_candidate('nova') }}"
          vncserver_proxyclient_address: "{{ get_candidate('nova') }}"
          auth_strategy: "keystone"
          network_api_class: "nova.network.neutronv2.api.API"
          neutron_url: "http://{{ get_candidate('neutron') }}:9696"
          neutron_auth_strategy: "keystone"
          neutron_admin_tenant_name: "service"
          neutron_admin_username: "neutron"
          neutron_admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
          neutron_admin_auth_url: "http://{{ get_candidate('keystone') }}:35357/v2.0"
          linuxnet_interface_driver: "nova.network.linux_net.LinuxOVSInterfaceDriver"
          firewall_driver: "nova.virt.firewall.NoopFirewallDriver"
          security_group_api: "neutron"
          service_neutron_metadata_proxy: "true"
          neutron_metadata_proxy_shared_secret: "{{ salt['pillar.get']('neutron:metadata_secret') }}"
          vif_plugging_is_fatal: "False"
          vif_plugging_timeout: "0"
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: "35357"
          auth_protocol: "http"
          admin_tenant_name: "service"
          admin_user: "nova"
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:nova:password') }}"
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:nova:username', default='nova') }}:{{ salt['pillar.get']('databases:nova:password', default='nova_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:nova:db_name', default='nova') }}"
    - require:
      - pkg: nova_api_install
      - pkg: nova_conductor_install
      - pkg: nova_scheduler_install
      - pkg: nova_cert_install
      - pkg: nova_consoleauth_install
      - pkg: python_novaclient_install
      - pkg: nova_novncproxy_install
      - pkg: nova_ajax_console_proxy_install
      - pkg: novnc_install

nova_sqlite_delete:
  file:
    - absent
    - name: /var/lib/nova/nova.sqlite
    - require:
      - file: nova_conf

nova_sync: 
  cmd: 
    - run
    - name: "{{ salt['pillar.get']('databases:nova:db_sync') }}"
    - require: 
      - file: nova_sqlite_delete

nova_api_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:nova_api', default='nova-api') }}"
    - require:
      - pkg: nova_api_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_cert_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:nova_cert', default='nova-cert') }}"
    - require:
      - pkg: nova_cert_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_consoleauth_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:nova_consoleauth', default='nova-consoleauth') }}"
    - require:
      - pkg: nova_consoleauth_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_scheduler_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:nova_scheduler', default='nova-scheduler') }}"
    - require:
      - pkg: nova_scheduler_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_conductor_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:nova_conductor', default='nova-conductor') }}"
    - require:
      - pkg: nova_conductor_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_novncproxy_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:nova_novncproxy', default='nova-novncproxy') }}"
    - require:
      - pkg: nova_novncproxy_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: nova_api_running
      - service: nova_cert_running
      - service: nova_consoleauth_running
      - service: nova_scheduler_running
      - service: nova_conductor_running
      - service: nova_novncproxy_running
