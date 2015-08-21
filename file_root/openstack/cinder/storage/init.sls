{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.cinder.storage.packages
  - openstack.cinder.loopback_file
  - openstack.cinder.message_queue.{{ openstack_parameters['series'] }}.{{ openstack_parameters['message_queue'] }}
  - openstack.cinder.storage.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
  - openstack.cinder.storage.{{ grains['os'] }}.mount_volumes_on_boot
