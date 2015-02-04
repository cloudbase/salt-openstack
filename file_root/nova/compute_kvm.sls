{% from "cluster/resources.jinja" import get_candidate with context %}

nova_compute_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:nova_compute') }}

{% if grains['os'] == 'Ubuntu' %}
nova_compute_kvm_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:nova_compute_kvm') }}

python_guestfs_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:python_guestfs') }}
{% endif %}

{% if pillar['cluster_type'] == 'juno' %}
sysfsutils_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:sysfsutils') }}
{% endif %}

{% if grains['os'] == 'Ubuntu' %}
nova_compute_conf:
  file: 
    - managed
    - name: {{ salt['pillar.get']('conf_files:nova_compute') }}
    - user: nova
    - group: nova
    - mode: 644
    - require: 
      - ini: nova_compute_conf
  ini: 
    - options_present
    - name: {{ salt['pillar.get']('conf_files:nova_compute') }}
    - sections: 
        DEFAULT: 
          cpu_mode: none
    - require: 
      - pkg: nova_compute_install
      - pkg: nova_compute_kvm_install
      - pkg: python_guestfs_install
{% endif %}

nova_conf_compute: 
  file: 
    - managed
    - name: {{ salt['pillar.get']('conf_files:nova') }}
    - user: nova
    - password: nova
    - mode: 644
    - require: 
      - ini: nova_conf_compute
  ini: 
    - options_present
    - name: {{ salt['pillar.get']('conf_files:nova') }}
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
          my_ip: {{ get_candidate('nova.compute_kvm') }}
          vnc_enabled: True
          vncserver_listen: 0.0.0.0
          vncserver_proxyclient_address: {{ get_candidate('nova.compute_kvm') }}
          novncproxy_base_url: "http://{{ get_candidate('nova') }}:6080/vnc_auto.html"
{% if pillar['cluster_type'] == 'juno' %}
        glance:
          host: "{{ get_candidate('glance') }}"
{% else %}
          glance_host: {{ get_candidate('glance') }}
{% endif %}
        keystone_authtoken: 
{% if pillar['cluster_type'] == 'juno' %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          identity_uri: http://{{ get_candidate('keystone') }}:35357
{% else %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: {{ get_candidate('keystone') }}
          auth_port: 35357
          auth_protocol: http
{% endif %}
          admin_tenant_name: service
          admin_user: nova
          admin_password: {{ salt['pillar.get']('keystone:tenants:service:users:nova:password') }}
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:nova:username') }}:{{ salt['pillar.get']('databases:nova:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:nova:db_name') }}"
        libvirt:
          virt_type: kvm
          cpu_mode: none
    - require: 
      - pkg: nova_compute_install
{% if grains['os'] == 'Ubuntu' %}
      - pkg: nova_compute_kvm_install
      - pkg: python_guestfs_install
{% endif %}

{% if grains['os'] == 'Ubuntu' %}
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
{% endif %}

nova_sqlite_compute_delete:
  file:
    - absent
    - name: /var/lib/nova/nova.sqlite
    - require:
      - pkg: nova_compute_install
{% if grains['os'] == 'Ubuntu' %}
      - pkg: nova_compute_kvm_install
      - pkg: python_guestfs_install
{% endif %}

{% if grains['os'] == 'CentOS' %}
chown_kvm:
  cmd: 
    - run
    - name: chown root:kvm /dev/kvm
    - require:
      - pkg: nova_compute_install

libvirtd_running:
  service: 
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:libvirtd') }}
    - require:
      - pkg: sysfsutils_install
    - watch: 
      - file: nova_conf_compute
      - ini: nova_conf_compute
{% endif %}

nova_compute_running:
  service: 
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:nova_compute') }}
    - require: 
      - pkg: nova_compute_install
{% if grains['os'] == 'Ubuntu' %}
      - pkg: nova_compute_kvm_install
      - pkg: python_guestfs_install
{% endif %}
    - watch: 
      - file: nova_conf_compute
      - ini: nova_conf_compute
{% if grains['os'] == 'Ubuntu' %}
      - file: nova_compute_conf
      - ini: nova_compute_conf
{% endif %}

nova_compute_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: nova_compute_running
