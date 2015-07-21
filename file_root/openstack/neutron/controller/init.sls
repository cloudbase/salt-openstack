{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.neutron.controller.packages
  - openstack.neutron.message_queue.{{ openstack_parameters['series'] }}.{{ openstack_parameters['message_queue'] }}
  - openstack.neutron.controller.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
