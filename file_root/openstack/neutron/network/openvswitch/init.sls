{% set neutron = salt['openstack_utils.neutron']() %}


include:
{% if salt['openstack_utils.boolean_value'](neutron['single_nic']['enable']) %}
  - openstack.neutron.network.openvswitch.single_nic
  - openstack.neutron.network.{{ grains['os'] }}.openvswitch.single_nic
{% else %}
  - openstack.neutron.network.openvswitch.multi_nic
  - openstack.neutron.network.{{ grains['os'] }}.openvswitch.multi_nic
{% endif %}