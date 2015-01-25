{% from "cluster/resources.jinja" import get_candidate with context %}

lvm_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:lvm') }}

cinder_volume_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_volume') }}"

{% if grains['os'] == 'CentOS' %}
targetcli_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:targetcli') }}"

cinder_olso_db_python_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:olso_db_python') }}"
{% endif %}

{% if salt['cmd.run']('losetup -a | grep "%s"' % salt['pillar.get']('cinder:volumes_path')) %}
cinder_vg_delete:
  cmd:
    - run
    - name: vgremove -f {{ salt['pillar.get']('cinder:volumes_group_name') }}

cinder_pv_delete:
  cmd:
    - run
    - name: pvremove -y {{ salt['pillar.get']('cinder:loopback_device') }}

cinder_lv_delete:
  cmd:
    - run
    - name: 'losetup -d {{ salt['pillar.get']('cinder:loopback_device') }}'
{% endif %}

{% set count = ((salt['pillar.get']('cinder:volumes_group_size')|int)*(2**30)/4096)|int %}
dd_cmd:
  cmd:
    - run
    - name: dd if=/dev/zero of={{ salt['pillar.get']('cinder:volumes_path') }} bs=4K count={{ (count+(0.03*count))|int }}

cinder_volumes:
  file:
    - managed
    - name: {{ salt['pillar.get']('cinder:volumes_path') }}
    - user: cinder
    - group: cinder
    - mode: 644
    - require: 
      - cmd: dd_cmd

losetup_cmd:
  cmd:
    - run
    - name: losetup {{ salt['pillar.get']('cinder:loopback_device') }} {{ salt['pillar.get']('cinder:volumes_path') }}
    - require: 
      - file: cinder_volumes

{% if grains['os'] == 'CentOS' %}
lvm_service:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:lvm') }}"
    - require:
      - pkg: lvm_install
{% endif %}

cinder_volumes_create:
  cmd:
    - run
    - name: |
        set -e
        pvcreate {{ salt['pillar.get']('cinder:loopback_device') }}
        vgcreate {{ salt['pillar.get']('cinder:volumes_group_name') }} {{ salt['pillar.get']('cinder:loopback_device') }}
    - require: 
      - cmd: losetup_cmd

cinder_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:cinder') }}"
    - user: cinder
    - group: cinder
    - mode: 644
    - require: 
      - ini: cinder_conf
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:cinder') }}"
    - sections:
        DEFAULT:
          my_ip: "{{ get_candidate('cinder.volume') }}"
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_port: 5672
          rabbit_userid: guest
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
          glance_host: "{{ get_candidate('glance') }}"
          volume_group: {{ salt['pillar.get']('cinder:volumes_group_name') }}
{% if pillar['cluster_type'] == 'juno' and grains['os'] == 'CentOS' %}
          iscsi_helper: lioadm
{% endif %}
        database:
          connection: "mysql://{{ salt['pillar.get']('databases:cinder:username') }}:{{ salt['pillar.get']('databases:cinder:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:cinder:db_name') }}"
        keystone_authtoken:
{% if pillar['cluster_type'] == 'juno' %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          identity_uri: http://{{ get_candidate('keystone') }}:35357
{% else %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
{% endif %}
          admin_tenant_name: service
          admin_user: cinder
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:cinder:password') }}"
    - require:
      - pkg: cinder_volume_install

{% if grains['os'] == 'CentOS' and grains['osrelease_info'][0] == 7 %}
cinder_volumes_systemd_service:
  file:
    - managed
    - name: "/lib/systemd/system/openstack-losetup.service"
    - user: root
    - group: root
    - mode: 644
    - require:
      - ini: cinder_volumes_systemd_service
  ini:
    - options_present
    - name: "/lib/systemd/system/openstack-losetup.service"
    - sections:
        Unit:
          Description: "Setup cinder-volume loop device"
          DefaultDependencies: "false"
          Before: "openstack-cinder-volume.service"
          After: "local-fs.target"
        Service:
          Type: "oneshot"
          ExecStart: "/usr/bin/sh -c '/usr/sbin/losetup -j {{ salt['pillar.get']('cinder:volumes_path') }} | /usr/bin/grep {{ salt['pillar.get']('cinder:volumes_path') }} || /usr/sbin/losetup -f {{ salt['pillar.get']('cinder:volumes_path') }}'"
          ExecStop: "/usr/bin/sh -c '/usr/sbin/losetup -j {{ salt['pillar.get']('cinder:volumes_path') }} | /usr/bin/cut -d : -f 1 | /usr/bin/xargs /usr/sbin/losetup -d'"
          TimeoutSec: "60"
          RemainAfterExit: "yes"
        Install:
          RequiredBy: "openstack-cinder-volume.service"
    - require:
      - cmd: cinder_volumes_create

cinder_volumes_losetup_running:
  service:
    - running
    - enable: True
    - name: openstack-losetup
    - require:
      - file: cinder_volumes_systemd_service
{% endif %}

cinder_volume_service:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:cinder_volume') }}"
    - require:
      - pkg: cinder_volume_install
    - watch:
      - file: cinder_conf
      - ini: cinder_conf
      - cmd: cinder_volumes_create

cinder_iscsi_target_service:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:iscsi_target') }}"
    - require:
      - pkg: cinder_volume_install
{% if grains['os'] == 'CentOS' %}
      - pkg: targetcli_install
{% endif %}
    - watch:
      - file: cinder_conf
      - ini: cinder_conf
      - cmd: cinder_volumes_create

cinder_volume_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: cinder_volume_service
      - service: cinder_iscsi_target_service
