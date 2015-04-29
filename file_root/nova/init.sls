{% from "cluster/resources.jinja" import get_candidate with context %}

nova_api_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_api') }}"

nova_cert_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_cert') }}"

nova_conductor_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_conductor') }}"

nova_consoleauth_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_consoleauth') }}"

nova_novncproxy_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_novncproxy') }}"

nova_scheduler_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_scheduler') }}"

python_novaclient_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_pythonclient') }}"

{% if grains['os'] == 'Ubuntu' %}
nova_ajax_console_proxy_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:nova_ajax_console_proxy') }}"

novnc_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:novnc') }}"
{% endif %}

nova_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:nova') }}"
    - user: nova
    - group: nova
    - mode: 644
    - require:
      - ini: nova_conf
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:nova') }}"
    - sections: 
        DEFAULT: 
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
          auth_strategy: "keystone"
          my_ip: "{{ get_candidate('nova') }}"
          vncserver_listen: "{{ get_candidate('nova') }}"
          vncserver_proxyclient_address: "{{ get_candidate('nova') }}"
          cpu_allocation_ratio: {{ salt['pillar.get']('nova:cpu_allocation_ratio') }}
          ram_allocation_ratio: {{ salt['pillar.get']('nova:ram_allocation_ratio') }}
{% if pillar['cluster_type'] == 'juno' %}
        glance:
          host: "{{ get_candidate('glance') }}"
{% else %}
          glance_host: {{ get_candidate('glance') }}
{% endif %}
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
{% if pillar['cluster_type'] == 'juno' %}
          identity_uri: http://{{ get_candidate('keystone') }}:35357
{% else %}
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: "35357"
          auth_protocol: "http"
{% endif %}
          admin_tenant_name: "service"
          admin_user: "nova"
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:nova:password') }}"
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:nova:username') }}:{{ salt['pillar.get']('databases:nova:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:nova:db_name') }}"
    - require:
      - pkg: nova_api_install
      - pkg: nova_conductor_install
      - pkg: nova_scheduler_install
      - pkg: nova_cert_install
      - pkg: nova_consoleauth_install
      - pkg: nova_novncproxy_install
      - pkg: python_novaclient_install
{% if grains['os'] == 'Ubuntu' %}
      - pkg: nova_ajax_console_proxy_install
      - pkg: novnc_install
{% endif %}

nova_sqlite_delete:
  file:
    - absent
    - name: /var/lib/nova/nova.sqlite
    - require:
      - file: nova_conf

nova_sync: 
  cmd: 
    - run
    - name: "su -s /bin/sh -c 'nova-manage db sync' nova"
    - require: 
      - file: nova_sqlite_delete

nova_api_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_api') }}"
    - require:
      - pkg: nova_api_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_cert_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_cert') }}"
    - require:
      - pkg: nova_cert_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_consoleauth_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_consoleauth') }}"
    - require:
      - pkg: nova_consoleauth_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_scheduler_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_scheduler') }}"
    - require:
      - pkg: nova_scheduler_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_conductor_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_conductor') }}"
    - require:
      - pkg: nova_conductor_install
    - watch:
      - file: nova_conf
      - ini: nova_conf
      - cmd: nova_sync

nova_novncproxy_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:nova_novncproxy') }}"
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
