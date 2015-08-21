{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - database.{{ openstack_parameters['database'] }}
  - database.{{ openstack_parameters['database'] }}.schema
