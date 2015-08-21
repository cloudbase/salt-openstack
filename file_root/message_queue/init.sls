{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - message_queue.{{ openstack_parameters['message_queue'] }}
