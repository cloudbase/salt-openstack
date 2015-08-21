{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.neutron.network.packages
  - openstack.neutron.message_queue.{{ openstack_parameters['series'] }}.{{ openstack_parameters['message_queue'] }}
  - openstack.neutron.network.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
  - openstack.neutron.network.openvswitch
