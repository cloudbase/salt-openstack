environment_name: "<environment_name>"

openstack_series: "<icehouse/juno/kilo>"

db_engine: "mysql"

message_queue_engine: "rabbitmq"

reset: "<soft/hard>"

debug_mode: <True/False>

system_upgrade: <True/False>

hosts:
  "<minion_id>": "<minion_management_ip_address>"

controller: "<minion_id>"
network: "<minion_id>"
storage:
  - "<minion_id>"
compute:
  - "<minion_id>"

cinder:
  volumes_group_name: "cinder-volumes"
  volumes_path: "/var/lib/cinder/cinder-volumes"
  volumes_group_size: "<volumes_group_size_in_gigabytes>"
  loopback_device: "/dev/loop0"

nova:
  cpu_allocation_ratio: "16"
  ram_allocation_ratio: "1.5"

glance:
  images:
    <image_name>:
      user: "<user_name>"
      tenant: "<tenant_name>"
      parameters:
        min_disk: "<minimum_needed_disk_in_gigabytes>"
        min_ram: "<minimum_needed_ram_in_megabytes>"
        copy_from: "<image_url>"
        disk_format: "<raw,vhd,vmdk,vdi,iso,qcow2,aki,ari,ami>"
        container_format: "<container_format_name>"
        is_public: <True/False>
        protected: <True/False>
