{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.neutron.compute.packages
  - openstack.neutron.message_queue.{{ openstack_parameters['series'] }}.{{ openstack_parameters['message_queue'] }}
  - openstack.neutron.compute.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
