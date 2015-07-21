{% set cinder = salt['openstack_utils.cinder']() %}


hard_reset_storage_losetup_absent:
  file.absent:
    - name: {{ cinder['conf']['losetup_upstart'] }}
