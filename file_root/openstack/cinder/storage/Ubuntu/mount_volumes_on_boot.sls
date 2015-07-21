{% set cinder = salt['openstack_utils.cinder']() %}


cinder_storage_losetup_upstart_job:
  file.managed:
    - name: "{{ cinder['conf']['losetup_upstart'] }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |

        start on started {{ cinder['services']['storage']['cinder_volume'] }}

        script
            #!/usr/bin/env bash
            if [ "`losetup -a | grep {{ cinder['volumes_path'] }}`" = "" ]; then
                losetup -f {{ cinder['volumes_path'] }} && vgchange -a y {{ cinder['volumes_group_name'] }} && service {{ cinder['services']['storage']['cinder_volume'] }} restart
            fi
        end script
    - require:
      - cmd: cinder_storage_vg_create

