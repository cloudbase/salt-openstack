{% set cinder = salt['openstack_utils.cinder']() %}


cinder_storage_systemd_service:
  ini.options_present:
    - name: {{ cinder['conf']['losetup_systemd'] }}
    - sections:
        Unit:
          Description: "Setup cinder-volume loop device"
          DefaultDependencies: "false"
          Before: "{{ cinder['services']['storage']['cinder_volume'] }}.service"
          After: "local-fs.target"
        Service:
          Type: "oneshot"
          ExecStart: "/usr/bin/sh -c '/usr/sbin/losetup -j {{ cinder['volumes_path'] }} | /usr/bin/grep {{ cinder['volumes_path'] }} || /usr/sbin/losetup -f {{ cinder['volumes_path'] }}'"
          ExecStop: "/usr/bin/sh -c '/usr/sbin/losetup -j {{ cinder['volumes_path'] }} | /usr/bin/cut -d : -f 1 | /usr/bin/xargs /usr/sbin/losetup -d'"
          TimeoutSec: "60"
          RemainAfterExit: "yes"
        Install:
          RequiredBy: "{{ cinder['services']['storage']['cinder_volume'] }}.service"


cinder_storage_losetup_service_enabled:
  service.enabled:
    - name: "{{ salt['openstack_utils.systemd_service_name'](cinder['conf']['losetup_systemd']) }}"
    - require:
      - ini: cinder_storage_systemd_service
