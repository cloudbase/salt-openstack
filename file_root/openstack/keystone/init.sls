{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.keystone.packages
  - openstack.keystone.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
  - openstack.keystone.tenants
  - openstack.keystone.users
  - openstack.keystone.services
