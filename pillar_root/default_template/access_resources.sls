
mysql: 
  root_password: "<password_value>"

rabbitmq:
  guest_password: "<password_value>"

databases: 
  nova: 
    db_name: "nova"
    username: "nova"
    password: "<password_value>"
  keystone: 
    db_name: "keystone"
    username: "keystone"
    password: "<password_value>"
  cinder: 
    db_name: "cinder"
    username: "cinder"
    password: "<password_value>"
  glance: 
    db_name: "glance"
    username: "glance"
    password: "<password_value>"
  neutron: 
    db_name: "neutron"
    username: "neutron"
    password: "<password_value>"
  heat:
    db_name: "heat"
    username: "heat"
    password: "<password_value>"

keystone: 
  admin_token: "<secret_token>"
  roles: 
    - "admin"
    - "heat_stack_owner"
    - "heat_stack_user"
  tenants: 
    admin: 
      users: 
        admin: 
          password: "<password_value>"
          roles: "[\"admin\", \"heat_stack_owner\"]"
          email: "salt@openstack.com"
    service: 
      users: 
        cinder: 
          password: "<password_value>"
          roles: "[\"admin\"]"
          email: "salt@openstack.com"
        glance: 
          password: "<password_value>"
          roles: "[\"admin\"]"
          email: "salt@openstack.com"
        neutron: 
          password: "<password_value>"
          roles: "[\"admin\"]"
          email: "salt@openstack.com"
        nova:
          password: "<password_value>"
          roles: "[\"admin\"]"
          email: "salt@openstack.com"
        heat:
          password: "<password_value>"
          roles: "[\"admin\"]"
          email: "salt@openstack.com"
        heat-cfn:
          password: "<password_value>"
          roles: "[\"admin\"]"
          email: "salt@openstack.com"
  services: 
    glance: 
      service_type: "image"
      endpoint: 
        adminurl: "http://{0}:9292"
        internalurl: "http://{0}:9292"
        publicurl: "http://{0}:9292"
        endpoint_host_sls: glance
      description: "glance image service"
    keystone: 
      service_type: "identity"
      endpoint: 
        adminurl: "http://{0}:35357/v2.0"
        internalurl: "http://{0}:5000/v2.0"
        publicurl: "http://{0}:5000/v2.0"
        endpoint_host_sls: keystone
      description: "Openstack Identity"
    neutron: 
      service_type: "network"
      endpoint: 
        adminurl: "http://{0}:9696"
        internalurl: "http://{0}:9696"
        publicurl: "http://{0}:9696"
        endpoint_host_sls: neutron
      description: "Openstack network service"
    nova: 
      service_type: "compute"
      endpoint: 
        adminurl: "http://{0}:8774/v2/%(tenant_id)s"
        internalurl: "http://{0}:8774/v2/%(tenant_id)s"
        publicurl: "http://{0}:8774/v2/%(tenant_id)s"
        endpoint_host_sls: nova
      description: "nova compute service"
    cinder:
      service_type: "volume"
      endpoint:
        adminurl: "http://{0}:8776/v1/%(tenant_id)s"
        internalurl: "http://{0}:8776/v1/%(tenant_id)s"
        publicurl: "http://{0}:8776/v1/%(tenant_id)s"
        endpoint_host_sls: cinder
      description: "OpenStack Block Storage"
    cinderv2:
      service_type: "volumev2"
      endpoint:
        adminurl: "http://{0}:8776/v2/%(tenant_id)s"
        internalurl: "http://{0}:8776/v2/%(tenant_id)s"
        publicurl: "http://{0}:8776/v2/%(tenant_id)s"
        endpoint_host_sls: cinder
      description: "OpenStack Block Storage V2"
    heat:
      service_type: "orchestration"
      endpoint:
        adminurl: "http://{0}:8004/v1/%(tenant_id)s"
        internalurl: "http://{0}:8004/v1/%(tenant_id)s"
        publicurl: "http://{0}:8004/v1/%(tenant_id)s"
        endpoint_host_sls: heat
      description: "Openstack Orchestration Service"
    heat-cfn:
      service_type: "cloudformation"
      endpoint:
        adminurl: "http://{0}:8000/v1"
        internalurl: "http://{0}:8000/v1"
        publicurl: "http://{0}:8000/v1"
        endpoint_host_sls: heat
      description: "Orchestration CloudFormation"
