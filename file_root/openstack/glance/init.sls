{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - openstack.glance.packages
  - openstack.glance.{{ grains['os'] }}.{{ openstack_parameters['series'] }}
  - openstack.glance.images
