{% set cinder = salt['openstack_utils.cinder']() %}


hard_reset_storage_losetup_service_dead:
  service.dead:
    - enable: False
    - name: "{{ salt['openstack_utils.systemd_service_name'](cinder['conf']['losetup_systemd']) }}"


hard_reset_storage_losetup_systemd_delete:
  file.absent:
    - name: "{{ cinder['conf']['losetup_systemd'] }}"