{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.cinder.controller.packages
  - openstack.cinder.controller.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
  - openstack.cinder.message_queue.{{ openstack_parameters['series'] }}.{{ openstack_parameters['message_queue'] }}
