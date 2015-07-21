{% set cinder = salt['openstack_utils.cinder']() %}


{% set blocks_4k = ((cinder['volumes_group_size']|int)*(2**30)/4096)|int %}
cinder_storage_volumes_group_dd_file:
  cmd.run:
    - name: dd if=/dev/zero of={{ cinder['volumes_path'] }} bs=4K count={{ blocks_4k }}
    - unless: losetup {{ cinder['loopback_device'] }}
    - require:
{% for pkg in cinder['packages']['storage'] %}
      - pkg: cinder_storage_{{ pkg }}_install
{% endfor %}
  file.managed:
    - name: {{ cinder['volumes_path'] }}
    - user: cinder
    - group: cinder
    - mode: 644
    - unless: losetup {{ cinder['loopback_device'] }}
    - require: 
      - cmd: cinder_storage_volumes_group_dd_file


cinder_storage_lv_create:
  cmd.run:
    - name: losetup {{ cinder['loopback_device'] }} {{ cinder['volumes_path'] }}
    - unless: losetup {{ cinder['loopback_device'] }}
    - require: 
      - file: cinder_storage_volumes_group_dd_file


cinder_storage_pv_create:
  cmd.run:
    - name: pvcreate {{ cinder['loopback_device'] }}
    - unless: pvdisplay {{ cinder['loopback_device'] }}
    - require:
      - cmd: cinder_storage_lv_create


cinder_storage_vg_create:
  cmd.run:
    - name: vgcreate {{ cinder['volumes_group_name'] }} {{ cinder['loopback_device'] }}
    - unless: vgdisplay {{ cinder['volumes_group_name'] }}
    - require: 
      - cmd: cinder_storage_pv_create
