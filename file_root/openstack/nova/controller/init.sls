{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.nova.controller.packages
  - openstack.nova.message_queue.{{ openstack_parameters['series'] }}.{{ openstack_parameters['message_queue'] }}
  - openstack.nova.controller.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
