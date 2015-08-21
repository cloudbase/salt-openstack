{% set neutron = salt['openstack_utils.neutron']() %}
{% set rabbitmq = salt['openstack_utils.rabbitmq']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


neutron_rabbitmq_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections:
        DEFAULT:
          rpc_backend: "neutron.openstack.common.rpc.impl_kombu"
          rabbit_host: "{{ openstack_parameters['controller_ip'] }}"
          rabbit_userid: "{{ rabbitmq['user_name'] }}"
          rabbit_password: {{ rabbitmq['user_password'] }}

