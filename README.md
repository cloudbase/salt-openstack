## 1. Setting up SaltStack Environment

### 1.1 Install salt-master

On the master machine execute the following to install the salt-master package:

    sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo add-apt-repository ppa:saltstack/salt -y && \
    sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo apt-get install salt-master -y

### 1.2 Configure salt-master

Clone the salt-openstack cloudbase git repository: 

    git clone https://github.com/cloudbase/salt-openstack.git

Inside the repository, two folders are found:

- ``pillar_root`` - contains states with parameters needed for OpenStack;
- ``file_root`` - contains states, which upon execution on the minion, it will install necessary 
packages and do the needed configurations.

Add / Update the following configuration options in ``/etc/salt/master``

    pillar_roots:
      openstack:
        - <absolute_path_to_pillar_root>
    file_roots:
      openstack:
        - <absolute_path_to_file_root>
    jinja_trim_blocks: True
    jinja_lstrip_blocks: True

Restart the salt-master service:

    sudo service salt-master restart

### 1.3 Install salt-minion(s)

On the minion machine(s) execute execute the following to install the salt-minion package:

    sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo add-apt-repository ppa:saltstack/salt -y && \
    sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo apt-get install salt-minion -y

### 1.4 Configure salt-minion(s)

As a requirement for OpenStack, ``Network Manager`` service must be disabled and salt-minion(s) must not depened on it.

It is recommended to change the minion’s id since any machine identification in SaltStack is based on the minion id, thus needed for deploying OpenStack. Minion id defaults to the FQDN of that machine. 

Edit ``/etc/salt/minion_id`` and change the default value.

Add the salt-master ip address to ``/etc/salt/minion`` conf file by executing the following 
command: 

    sudo sh -c "echo 'master: <master_ip_address>' >> /etc/salt/minion"
  
Execute the following commands to enable logging to a file and debug level:

    sudo sh -c "echo 'log_file: /var/log/salt/minion' >> /etc/salt/minion"
    sudo sh -c "echo 'log_level_logfile: debug' >> /etc/salt/minion"

Restart the salt-minion service:

    sudo service salt-minion restart

Instructions on how to set up Salt on a different operating system can be found at this link: http://docs.saltstack.com/en/latest/topics/installation/

### 1.5 Establish connectivity between salt-master and salt-minion

At this point minion machine tries to connect the the master machine. In order to allow this connection, the minion key has to be accepted by the master. On the master machine, execute the following command:

    sudo salt-key -a '<minion_id>' -y

Execute ``sudo salt-key -L`` on master machine and the following output is given:

    Accepted Keys:
    <minion_id>
    Unaccepted Keys:
    Rejected Keys:

It means that the minion with the id ``<minion_id>`` is connected to the master.

Test the master - minion connectivity by trying to ping the minion machine from the master. On the salt master execute:

    sudo salt '<minion_id>' test.ping

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

- OpenStack release name

        cluster_type

 The OpenStack release which will be installed. At the moment only: ``juno`` and ``icehouse``.

- Reset type to be applied on the targeted minion(s)

        reset

 Reset feature is used to remove or reconfigure a previously deployed OpenStack environment. This key accepts one of the following values: ``hard`` or ``soft``, depending on the required reset type.

 Reset types details:

  - ``Hard`` reset: It should be used when a previously deployed OpenStack is broken / nonfunctional. 

    **WARNING**: Hard reset states will purge all OpenStack packages and their dependencies (MySQL, RabbitMQ, OpenvSwitch, Apache and Memcached). This **MUST** not be used if there are, on the minion, other services using these dependencies.

  - ``Soft`` reset: It should be used when a previously deployed OpenStack is functional (all OpenStack services are up and running) and only reconfiguration is needed (based on the new pillar parameters).

    - Soft reset states will **NOT** run, if all OpenStack services are not running.
    - Soft reset states will execute commands on the controller node that will delete (from every tenant) the following elements: heat stacks, cinder volumes, nova instances, neutron networks / subnets / routers, glance images, etc.

  **NOTE**: Reset feature will not reconfigure single NIC Openstack environment to multi-NIC OpenStack environment.

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
          disk_format: "<raw,vhd,vmdk,vdi,iso,qcow2,aki,ari,ami>"
          container_format: "<bare,ovf,aki,ari,ami,ova>"
          is_public: "<True/False>"
          protected: "<True/False>"

 After glance is installed, the image is downloaded from the given ``<image_url>`` and uploaded to glance into the tenant ``<tenant_name>`` using the user with username ``<user_name>``. 

- Value of the total cinder volumes group size given in gigabytes.

        cinder:volumes_group_size

- Value of the nova cpu allocation ratio configuration (defaults to 16).

        nova:cpu_allocation_ratio

- Value of the nova ram allocation ratio configuration (defaults to 1.5).

        nova:ram_allocation_ratio

- Absolute path where keystonerc for user admin will be saved on the salt-minion(s)

        files:keystone_admin:path


### 2.3 Edit network_resources.sls file

- Secret token used by neutron

        neutron:metadata_secret

- Boolean value to enable / disable single NIC OpenStack deployment

        single_nic:enable
 
 In case this value is set to ``True``, ``br-proxy`` needs to be set up as it is needed for single NIC OpenStack. Configuration is made and after the OpenStack deployment is done, networking service just needs to be restarted to have this set up.
 
 **NOTE**: Due to a bug on Ubuntu 14.04 that networking service cannot be stopped / restarted, a bash script is created to set ``br-proxy`` up. At the end of salt-scripts execution, it can be found on the salt-minion at the default location ``/root/set-br-proxy.sh``

- Name of the network interface used in the single NIC OpenStack deployment

        single_nic:interface

- Name of bridge used for external network traffic

        neutron:external_bridge

- Openvswitch physnets mappings

        neutron:type_drivers:<network_type>:physnets

 The physnet is a mapping between an arbitrary name and the network bridge from specified minion machine. Configuration is made that will map the arbitrary name with the network bridge. Current saltstack scripts support the following network types: ``vxlan``, ``vlan``, ``gre`` and ``flat``.

 Add flat, vxlan or gre physnets under **neutron:type_drivers:&lt;flat/vxlan/gre&gt;:physnets** section using the following structure:

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

- Boolean flag to enable tunneling for OpenStack

        neutron:tunneling:enable

- The following settings will be applied only if ``neutron:tunneling:enable`` is set to ``True``

  - Neutron tunnel type. It takes one of the values: ``gre`` or ``vxlan``

          neutron:tunneling:tunnel_type

  - ``VXLAN`` and ``GRE`` tunnels definitions

    ``VXLAN`` tunnels can be defined under **neutron:type_drivers:vxlan:tunnels** section using the following structure:

          tunnels:
            <tunnel_name>:
              tunnel_id_ranges: "<start_tunnel_id>:<end_tunnel_id>"

    ``VXLAN`` multicast group address 

          neutron:type_drivers:vxlan:vxlan_group

    ``GRE`` tunnels can be defined under **neutron:type_drivers:gre:tunnels** section using the following structure:

          tunnels:
            <tunnel_name>:
              tunnel_id_ranges: "<start_tunnel_id>:<end_tunnel_id>"

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
            - direction: "<egress/ingress>"
              ethertype: "<IPv4/IPv6>"
              protocol: "<icmp/tcp/udp>"
              port_range_min: "<start_port>"
              port_range_max: "<end_port>"
              remote_ip_prefix: "<cidr>"


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

    sudo salt -L '<minion_id_1>,<minion_id_2>' saltutil.refresh_pillar                         
    # It will make the OpenStack parameters available on the targeted minion(s).

    sudo salt -L '<minion_id_1>,<minion_id_2>' saltutil.sync_all                               
    # It will upload all of the custom dynamic modules to the targeted minion(s). 
    # Custom modules for OpenStack (network create, router create, security group create, etc.) have been defined.

    sudo salt -C 'I@cluster_name:<cluster_name>' state.highstate  
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

OpenStack is installed using SaltStack. Depending on your Linux distribution, horizon can be accessed at the URL:

 - ``http://<minion_ip_address>/horizon`` for Ubuntu
 - ``http://<minion_ip_address>/dashboard`` for CentOS

# How-To Section

### 1. Run the SaltStack OpenStack states on a masterless minion

For scenarios when just a single OpenStack all-in-one is needed, it is prefered to run the salt-scripts locally on a masterless minion machine.

Steps on how to install and configure masterless minion machine:

  - Install and configure a simple minion machine following instructions from ``section 1.3`` and ``section 1.4``.

  - Instruct the minion to not look for a master machine when searching for ``file_root`` and ``pillar_root`` folders. This way, it searches locally for the salt-openstack states.

        sudo sh -c "echo 'file_client: local' >> /etc/salt/minion"

  - Clone the salt-openstack cloudbase git repository:

        git clone https://github.com/cloudbase/salt-openstack.git

  - Add / Update the following configuration options in ``/etc/salt/minion``.

        pillar_roots:
          openstack:
            - <absolute_path_to_pillar_root>
        file_roots:
          openstack:
            - <absolute_path_to_file_root>
        jinja_trim_blocks: True
        jinja_lstrip_blocks: True

  - Stop the ``salt-minion`` daemon. Otherwise the minion attempts to connect to a master and it will fail.

        sudo service salt-minion stop

  - Follow instructions from ``section 2`` and set up OpenStack parameters, but on the masterless minion instead on the master machine.

  - Set up ``top.sls`` file from ``pillar_root`` as described at the beginning of the ``section 3``. The masterless minion is the only one targeted when running the salt-openstack scripts.

  - Run the salt-scripts commands as described in ``section 3``, but this time locally:

        sudo salt-call --local saltutil.refresh_pillar
        sudo salt-call --local saltutil.sync_all
        sudo salt-call --local state.highstate

  - OpenStack all-in-one is now installed on the masterless salt-minion machine.
