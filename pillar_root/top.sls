openstack: 
  "<minion_id_1>,<minion_id_2>":
    - match: list
    - {{ grains['os'] }}
    - <openstack_environment_name>.credentials
    - <openstack_environment_name>.environment
    - <openstack_environment_name>.networking
