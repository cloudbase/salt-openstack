####################################
###    STORAGE NODE HARD RESET   ###
####################################

{% set cinder = salt['openstack_utils.cinder']() %}


{% set storage_services = salt['openstack_utils.os_services']('storage') %}
{% for service in storage_services %}
hard_reset_storage_{{ service }}_stopped:
  service.dead:
    - enable: False
    - name: {{ service }}
{% endfor %}


{% set storage_packages = salt['openstack_utils.os_packages']('storage') %}
{% for pkg in storage_packages %}
hard_reset_storage_{{ pkg }}_purged:
  pkg.purged:
    - pkgs:
      - {{ pkg }}
{% endfor %}


hard_reset_storage_vg_delete:
  cmd.run:
    - name: vgremove -f {{ cinder['volumes_group_name'] }}
    - onlyif: vgdisplay {{ cinder['volumes_group_name'] }}


hard_reset_storage_pv_delete:
  cmd.run:
    - name: pvremove -y {{ cinder['loopback_device'] }}
    - onlyif: pvdisplay {{ cinder['loopback_device'] }}


hard_reset_storage_lv_delete:
  cmd.run:
    - name: losetup -d {{ cinder['loopback_device'] }}
    - onlyif: losetup {{ cinder['loopback_device'] }}


hard_reset_storage_volumes_file_delete:
  file.absent:
    - name: {{ cinder['volumes_path'] }}
