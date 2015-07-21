mysql:
  root_password: "<password_value>"

rabbitmq:
  user_name: "openstack"
  user_password: "<password_value>"

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

neutron:
  metadata_secret: "<password_value>"

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
          roles:
            - "admin"
            - "heat_stack_owner"
          email: "salt@openstack.com"
          keystonerc:
            create: <True/False>
            path: <keystonerc_path>
    service:
      users:
        cinder:
          password: "<password_value>"
          roles:
            - "admin"
          email: "salt@openstack.com"
        glance:
          password: "<password_value>"
          roles:
            - "admin"
          email: "salt@openstack.com"
        neutron:
          password: "<password_value>"
          roles:
            - "admin"
          email: "salt@openstack.com"
        nova:
          password: "<password_value>"
          roles:
            - "admin"
          email: "salt@openstack.com"
        heat:
          password: "<password_value>"
          roles:
            - "admin"
          email: "salt@openstack.com"
        heat-cfn:
          password: "<password_value>"
          roles:
            - "admin"
          email: "salt@openstack.com"
