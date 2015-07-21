{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.horizon.packages
  - openstack.horizon.{{ grains['os'] }}
