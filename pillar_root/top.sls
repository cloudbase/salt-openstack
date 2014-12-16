openstack: 
  "<minion_id_1>,<minion_id_2>":
    - match: list
    - {{ grains['os'] }}
    - <cluster_name>.cluster_resources
    - <cluster_name>.access_resources
    - <cluster_name>.network_resources