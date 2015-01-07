{% from "cluster/resources.jinja" import get_candidate with context %}

nova_compute_kvm_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:nova_compute_kvm', default='nova-compute-kvm') }}

nova_compute_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:nova_compute', default='nova-compute') }}

python_guestfs_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:python_guestfs', default='python-guestfs') }}

nova_compute_conf:
  file: 
    - managed
    - name: {{ salt['pillar.get']('conf_files:nova_compute', default='/etc/nova/nova-compute.conf') }}
    - user: nova
    - group: nova
    - mode: 644
    - require: 
      - ini: nova_compute_conf
  ini: 
    - options_present
    - name: {{ salt['pillar.get']('conf_files:nova_compute', default='/etc/nova/nova-compute.conf') }}
    - sections: 
        DEFAULT: 
          cpu_mode: none
    - require: 
      - pkg: nova_compute_install
      - pkg: nova_compute_kvm_install
      - pkg: python_guestfs_install

nova_conf_compute: 
  file: 
    - managed
    - name: {{ salt['pillar.get']('conf_files:nova', default='/etc/nova/nova.conf') }}
    - user: nova
    - password: nova
    - mode: 644
    - require: 
      - ini: nova_conf_compute
  ini: 
    - options_present
    - name: {{ salt['pillar.get']('conf_files:nova', default='/etc/nova/nova.conf') }}
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
          my_ip: {{ get_candidate('nova.compute_kvm') }}
          vnc_enabled: True
          vncserver_listen: 0.0.0.0
          vncserver_proxyclient_address: {{ get_candidate('nova.compute_kvm') }}
          novncproxy_base_url: "http://{{ get_candidate('nova') }}:6080/vnc_auto.html"
          glance_host: {{ get_candidate('glance') }}
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: {{ get_candidate('keystone') }}
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: nova
          admin_password: {{ salt['pillar.get']('keystone:tenants:service:users:nova:password') }}
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:nova:username', default='nova') }}:{{ salt['pillar.get']('databases:nova:password', default='nova_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:nova:db_name', default='nova') }}"
    - require: 
      - pkg: nova_compute_install
      - pkg: nova_compute_kvm_install
      - pkg: python_guestfs_install

nova_instance_directory: 
  file: 
    - directory
    - name: "/var/lib/nova/instances/"
    - user: nova
    - group: nova
    - mode: 755
    - recurse: 
      - user
      - group
      - mode
    - require: 
      - pkg: nova_compute_install
      - pkg: nova_compute_kvm_install
      - pkg: python_guestfs_install

nova_sqlite_compute_delete:
  file:
    - absent
    - name: /var/lib/nova/nova.sqlite
    - require:
      - pkg: nova_compute_kvm_install
      - pkg: nova_compute_install
      - pkg: python_guestfs_install
      - file: nova_conf_compute
      - ini: nova_conf_compute
      - file: nova_compute_conf
      - ini: nova_compute_conf

nova_compute_running:
  service: 
    - running
    - name: {{ salt['pillar.get']('services:nova_compute', default='nova-compute') }}
    - require: 
      - pkg: nova_compute_kvm_install
      - pkg: nova_compute_install
      - pkg: python_guestfs_install
    - watch: 
      - file: nova_conf_compute
      - ini: nova_conf_compute
      - file: nova_compute_conf
      - ini: nova_compute_conf
      - file: nova_sqlite_compute_delete

nova_compute_wait:
  cmd:
    - run
    - name: sleep 3
    - require:
      - service: nova_compute_running
