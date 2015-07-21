{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.heat.packages
  - openstack.heat.message_queue.{{ openstack_parameters['series'] }}.{{ openstack_parameters['message_queue'] }}
  - openstack.heat.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
