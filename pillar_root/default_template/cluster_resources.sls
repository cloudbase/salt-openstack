cluster_name: "<cluster_name>"

cluster_type: "<cluster_type>"

db_engine: "mysql"

queue_engine: "rabbit"

reset: "<soft/hard>"

hosts: 
  "<minion_id>": "<minion_management_ip_address>"

roles:
  - "controller"
  - "network"
  - "storage"
  - "compute"

controller: "<minion_id>"
network: "<minion_id>"
storage:
  - "<minion_id>"
compute: 
  - "<minion_id>"

sls: 
  - controller: 
    - "ntp"
    - "mysql"
    - "mysql.client"
    - "mysql.openstack_dbschema"
    - "queue.rabbit"
    - "keystone"
    - "keystone.openstack_tenants"
    - "keystone.openstack_users"
    - "keystone.openstack_services"
    - "glance"
    - "glance.images"
    - "nova"
    - "neutron"
    - "neutron.ml2"
    - "horizon"
    - "cinder"
    - "heat"
  - network: 
    - "mysql.client"
    - "neutron.services"
    - "neutron.ml2"
    - "neutron.openvswitch"
    - "neutron.networks"
    - "neutron.routers"
    - "neutron.security_groups"
  - compute: 
    - "mysql.client"
    - "nova.compute_kvm"
    - "neutron.openvswitch"
    - "neutron.ml2"
  - storage:
    - "mysql.client"
    - "cinder.volume"

glance:
  images:
    <image_name>:
      min_disk: "<minimum_needed_disk_in_gigabytes>"
      min_ram: "<minimum_needed_ram_in_megabytes>"
      copy_from: "<image_url>"
      user: "<user_name>"
      tenant: "<tenant_name>"
      disk_format: "<raw,vhd,vmdk,vdi,iso,qcow2,aki,ari,ami>"
      container_format: "<container_format_name>"
      is_public: "<True/False>"
      protected: "<True/False>"

cinder:
  volumes_group_name: "cinder-volumes"
  volumes_path: "/var/lib/cinder/cinder-volumes"
  volumes_group_size: "<volumes_group_size_in_gigabytes>"
  loopback_device: "/dev/loop0"

nova:
  cpu_allocation_ratio: "16"
  ram_allocation_ratio: "1.5"

files:
  keystone_admin:
    path: "<path_to_keystone_rc>"
