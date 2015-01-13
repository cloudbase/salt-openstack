## 1. Setting up SaltStack Environment

### 1.1 Install salt-master

On the master machine execute the following to install the salt-master package:

    apt-get update && \
    apt-get upgrade -y && \
    add-apt-repository ppa:saltstack/salt -y && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install salt-master -y

### 1.2 Configure salt-master

Clone the salt-openstack cloudbase repository: 

    git clone git@github.com:cloudbase/salt-openstack.git

Inside the repository, two folders are found:

- ``pillar_root`` - contains states with parameters needed for OpenStack;
- ``file_root`` - contains states, which upon execution on the minion, it will install necessary 
packages and do the needed configurations.

Add / Update the following configuration options in ``/etc/salt/master``

    pillar_roots:
      openstack:
        - <path_to_pillar_root>
    file_roots:
      openstack:
        - <path_to_file_root>
    jinja_trim_blocks: True
    jinja_lstrip_blocks: True

Restart the salt-master service:

    service salt-master restart

### 1.3 Install salt-minion(s)

On the minion machine(s) execute execute the following to install the salt-minion package:

    apt-get update && \
    apt-get upgrade -y && \
    add-apt-repository ppa:saltstack/salt -y && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install salt-minion -y

### 1.4 Configure salt-minion(s)

It is recommended to change the minion’s id since any machine identification in SaltStack is based on the minion id, thus needed for deploying OpenStack. Minion id defaults to the FQDN of that machine. 

Edit ``/etc/salt/minion_id`` and change the default value.

Add the salt-master ip address to ``/etc/salt/minion`` conf file by executing the following 
command: 

    echo "master: <master_ip_address>" >> /etc/salt/minion
  
Execute the following commands to enable logging to a file and debug level:

    echo "log_file: /var/log/salt/minion" >> /etc/salt/minion
    echo "log_level_logfile: debug" >> /etc/salt/minion

Restart the salt-minion service:

    service salt-minion restart

Instructions on how to set up Salt on a different operating system can be found at this link: http://docs.saltstack.com/en/latest/topics/installation/

### 1.5 Establish connectivity between salt-master and salt-minion

At this point minion machine tries to connect the the master machine. In order to allow this connection, the minion key has to be accepted by the master. On the master machine, execute the following command:

    salt-key -a '<minion_id>' -y

Execute ``salt-key -L`` on master machine and the following output is given:

    Accepted Keys:
    <minion_id>
    Unaccepted Keys:
    Rejected Keys:

It means that the minion with the id ``<minion_id>`` is connected to the master.

Test the master - minion connectivity by trying to ping the minion machine from the master. On the salt master execute:

    salt '<minion_id>' test.ping

The following output is given:

    '<minion_id>':
        True

This means that the minion machine successfully connected to the master machine.

## 2. Configure OpenStack parameters

Each OpenStack must have its own folder in the ``pillar_root`` with the necessary configurations. There is already a ``default_template`` folder in ``pillar_root`` with the skeleton of the pillar data, that each OpenStack environment must have set up. 

On the master machine, change directory to ``pillar_root``. Duplicate the folder  ``default_template`` and give it the name of a new OpenStack environment that it will be created. Inside the ``pillar_root`` folder execute the following command:

    cp -rf default_template <openstack_environment_name>

The following files from ``<openstack_environment_name>`` folder have to be edited before deploying OpenStack: 

- ``access_resources.sls`` (passwords and keystone related data)
- ``cluster_resources.sls`` (OpenStack environment information)
- ``network_resources.sls`` (OpenStack networking configuration).

As official OpenStack documentation recommends, strong passwords and tokens can be generated using: ``openssl rand -hex 10``

For each file inside ``<openstack_environment_name>`` folder from ``pillar_root``, edit the following configurations and leave the other options to the default value.

### 2.1 Edit access_resources.sls file

- Password used by the MySQL root user

        mysql:root_password

- RabbitMQ password used by the user guest

        rabbitmq:guest_password

- MySQL database password for each OpenStack service

        databases:<service_name>:password

 Databases section inside ``access_resources.sls`` contains information about the database of each service within OpenStack. Six services are available to be installed with the current SaltStack scripts: nova, keystone, cinder, glance, neutron and heat. Edit the password for each one of them.

- Admin token used by keystone service

        keystone:admin_token

- The password used by each tenant user

        keystone:tenants:<tenant_name>:users:<user_name>:password

 The **tenants** section under **keystone** contains information about the tenants and users to be created. By default only admin and service tenants are created. You can define more tenants and users to be created here. Use the following structure:

        <tenant_name>: 
          users: 
            <user1_name>: 
              password: "<user1_password"
              roles: "[\"<user1_role>\"]"
              email: "<user1_email>"
            <user2_name>: 
              password: "<user2_password"
              roles: "[\"<user2_role>\"]"
              email: "<user2_email>"


### 2.2 Edit cluster_resources.sls file

- OpenStack environment name

        cluster_name

 The cluster name should be the name of the folder with the pillar data.

- OpenStack nodes

 Add the management ip address of all your OpenStack nodes under the **hosts** section. Use the following structure:

        hosts:
          "<minion_id>": "<management_ip_address>"

- Mapping between roles and minion ids

        <role_name>:<minion_ids>

 Add every minion id under the role you want that minion to have. There are four roles defined with the following names: controller, network, storage and compute. 

 When you define the nodes for each role use the following structure: 

        controller: "<minion_id>"
        network: "<minion_id>"
        compute: 
          - "<minion_id_1>"
          - "<minion_id_2>"
        storage:
          - "<minion_id_1>"
          - "<minion_id_2>"


 There is:
  - One to one mapping between the roles controller, network and minions;
  - One to many mapping between the roles compute, storage and minions

- Custom images that you want to upload to glance here.

        glance:images

 Add custom images that you want to upload to glance here. Use the following structure:

        <image_name>:
          min_disk: "<minimum_needed_disk_in_gigabytes>"
          min_ram: "<minimum_needed_ram_in_megabytes>"
          copy_from: "<image_url>"
          user: "<user_name>"
          tenant: "<tenant_name>"

 After glance is installed, the image is downloaded from the given ``<image_url>`` and uploaded to glance into the tenant ``<tenant_name>`` using the user with username ``<user_name>``. 

- Path where keystonerc for user admin will be saved

        files:keystone_admin:path

- Value of the total cinder volumes group size given in gigabytes.

        cinder:volumes_group_size

### 2.3 Edit network_resources.sls file

- Secret token used by neutron

        neutron:metadata_secret

- Openvswitch physnets mappings

        neutron:type_drivers:<network_type>:physnets

 The physnet is a mapping between an arbitrary name and the network bridge from specified minion machine. Configuration is made that will map the arbitrary name with the network bridge. Current saltstack scripts support only flat and vlan network types.

 Add flat physnets under **neutron:type_drivers:flat:physnets** section using the following structure:

        <physnet_name>: 
          bridge: "<bridge_name>"
          hosts:
            <minion_id>: "<interface_name>"

 Add vlan physnets under **neutron:type_drivers:vlan:physnets** section using the following structure:

        <physnet_name>: 
          bridge: "<bridge_name>"
          vlan_range: "<start_vlan>:<end_vlan>"
          hosts:
            <minion_id>: "<interface_name>"

- Initial networks to be created within OpenStack

        neutron:networks:<network_name>

 In the network definition you also have to specify the subnets. Define networks under **neutron:networks** section with the following structure:

        <network_name>:
          user: <user_name>
          tenant: <tenant_name>
          provider_physical_network: <physnet_name>
          provider_network_type: <network_type>
          shared: <True/False>          # It can be omitted and it defaults to False
          admin_state_up: <True/False>  # It can be omitted and it defaults to True
          router_external: <True/False> # It can be omitted and it defaults to False
          subnets:
            <subnet_name>:
              cidr: '<cidr>'
              allocation_pools:
                - start: '<start_ip>'
                  end: '<end_ip>'
              enable_dhcp: <True/False> # It can be omitted and it defaults to True
              dns_nameservers:          # List of dns nameservers and it can be omitted
                - '8.8.8.8'

- Initially created OpenStack routers

        neutron:routers:<router_name>

 Add them under the **neutron:routers** section and use the following structure:

        routers:
          <router_name>:
            user: <user_name>
            tenant: <tenant_name>
            interfaces:         # list of subnets that will be connected to the router
              - <subnet_name_1>
              - <subnet_name_2>
            gateway_network: <network_name>

- Initially created OpenStack security groups

        neutron:security_groups:<group_name> 

 Add them under neutron:security_groups section and use the following structure:

        <security_group_name>:
          user: <user_name>
          tenant: <tenant_name>
          description: '<short_description>'
          rules:
            - protocol: <icmp/tcp/udp>
              direction: <egress/ingress>
              from-port: <start_port>
              to-port: <end_port>
              cidr: '<cidr>'

## 3. Install OpenStack

OpenStack parameters are configured and the environment is ready to be installed. Before running salt to install it, on the salt-master machine, edit ``top.sls`` file from ``pillar_root``.   

Top file determines which are the minions that will have OpenStack parameters available.

    openstack: 
      "<minion_id_1>,<minion_id_2>":
        - match: list
        - {{ grains['os'] }}
        - <openstack_environment_name>.cluster_resources
        - <openstack_environment_name>.access_resources
        - <openstack_environment_name>.network_resources

At line two from ``top.sls`` file, you specify the targeted minions. Give them as a comma separated list.

**IMPORTANT**:  Here, you must specify only the minions ids defined in the ``cluster_resources.sls`` file at **hosts** section. 

Also replace ``<openstack_environment_name>`` with the name of the folder from ``pillar_root`` that contains the OpenStack parameters.

OpenStack environment is ready to be installed.

On the salt master machine execute the following commands:

    salt '*' saltutil.refresh_pillar                         
    # It will make the OpenStack parameters available
    # on the targeted node(s)

    salt '*' saltutil.sync_all                               
    # It will upload all of the custom dynamic modules to 
    # minion(s). Custom modules for OpenStack (network create, router  
    # create, security group create, etc.) have been defined.

    salt -C 'I@cluster_name:<cluster_name>' state.highstate  
    # It will install the OpenStack environment

Replace ``<cluster_name>`` with the name of the OpenStack environment as defined in ``cluster_resources.sls`` file.

At the end of the execution, the following output is given:

    Summary
    --------------
    Succeeded: <total_states> (changed=<states_caused_changes>)
    Failed:      <failed_states>
    --------------
    Total states run:     <total_states>

A total number of ``<total_states>`` have been executed and ``<states_caused_changes>`` produced any change during the OpenStack installation.

``<failed_states>`` should be zero. In case it is higher than zero, check the logs on the minion(s) for errors details.
