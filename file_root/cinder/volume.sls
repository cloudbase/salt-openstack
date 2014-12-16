{% from "cluster/resources.jinja" import get_candidate with context %}

lvm_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:lvm', default='lvm2') }}

cinder_volume_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_volume', default='cinder-volume') }}"
    - require:
      - pkg: lvm_install

{% set count = ((salt['pillar.get']('cinder:volumes_group_size', default='30')|int)*(2**30)/4096)|int %}

dd_cmd:
  cmd:
    - run
    - name: dd if=/dev/zero of={{ salt['pillar.get']('cinder:volumes_path', default='/var/lib/cinder/cinder-volumes') }} bs=4K count={{ (count+(0.03*count))|int }}

cinder_volumes:
  file:
    - managed
    - name: "{{ salt['pillar.get']('cinder:volumes_path', default='/var/lib/cinder/cinder-volumes') }}"
    - user: cinder
    - group: cinder
    - mode: 644
    - require: 
      - cmd: dd_cmd

losetup_cmd:
  cmd:
    - run
    - name: losetup {{ salt['pillar.get']('cinder:loopback_device', default='/dev/loop0') }} {{ salt['pillar.get']('cinder:volumes_path', default='/var/lib/cinder/cinder-volumes') }}
    - require: 
      - file: cinder_volumes

pvcreate_cmd:
  cmd:
    - run
    - name: pvcreate {{ salt['pillar.get']('cinder:loopback_device', default='/dev/loop0') }}
    - require: 
      - cmd: losetup_cmd

vgcreate_cmd:
  cmd:
    - run
    - name: vgcreate {{ salt['pillar.get']('cinder:volumes_group_name', default='cinder-volumes') }} {{ salt['pillar.get']('cinder:loopback_device', default='/dev/loop0') }}
    - require:
      - cmd: pvcreate_cmd

cinder_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:cinder', default='/etc/cinder/cinder.conf') }}"
    - user: cinder
    - group: cinder
    - mode: 644
    - require: 
      - ini: cinder_conf
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:cinder', default='/etc/cinder/cinder.conf') }}"
    - sections:
        DEFAULT:
          my_ip: "{{ get_candidate('cinder.volume') }}"
          rpc_backend: "{{ salt['pillar.get']('queue_engine', default='rabbit') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_port: 5672
          rabbit_userid: guest
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
          glance_host: "{{ get_candidate('glance') }}"
          volume_group: {{ salt['pillar.get']('cinder:volumes_group_name', default='cinder-volumes') }}
        database:
          connection: "mysql://{{ salt['pillar.get']('databases:cinder:username', default='cinder') }}:{{ salt['pillar.get']('databases:cinder:password', default='cinder_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:cinder:db_name', default='cinder') }}"
        keystone_authtoken:
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: cinder
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:cinder:password') }}"
    - require:
      - pkg: cinder_volume_install

cinder_volume_service:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:cinder_volume', default='cinder-volume') }}"
    - require:
      - pkg: cinder_volume_install
    - watch:
      - file: cinder_conf
      - ini: cinder_conf
      - cmd: vgcreate_cmd

cinder_iscsi_target_service:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:iscsi_target', default='tgt') }}"
    - require:
      - pkg: cinder_volume_install
    - watch:
      - file: cinder_conf
      - ini: cinder_conf
      - cmd: vgcreate_cmd

cinder_volume_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: cinder_volume_service
      - service: cinder_iscsi_target_service
