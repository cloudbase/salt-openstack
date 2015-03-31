{% from "cluster/resources.jinja" import get_candidate with context %}

################################
###   OPENSTACK SOFT RESET   ###
################################


{% set keystone_admin_endpoint = salt['pillar.get']('keystone:services:keystone:endpoint:adminurl').format(get_candidate('keystone')) %}
{% set keystone_admin_token = salt['ini.get_option']("%s" % salt['pillar.get']('conf_files:keystone'), "DEFAULT", "admin_token") %}
{% set temporary_tenant_name = salt['random.get_str'](16) %}
{% set temporary_admin_name = salt['random.get_str'](16) %}
{% set temporary_admin_password = salt['random.get_str'](16) %}


# Check if all OpenStack controller services are running.
# Script will exit with 0 in one of the cases:
#  - all services are not installed (clean salt-minion);
#  - all services are installed and running.
# Otherwise, it will exit with 1.

services_check_script:
  file.managed:
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/services_check.sh"
    - contents: |
        #!/bin/bash
        set -e

{% set openstack_services = [ salt['pillar.get']('services:keystone'),
                              salt['pillar.get']('services:heat_api'),
                              salt['pillar.get']('services:heat_api_cfn'),
                              salt['pillar.get']('services:heat_engine'),
                              salt['pillar.get']('services:nova_api'),
                              salt['pillar.get']('services:nova_conductor'),
                              salt['pillar.get']('services:nova_scheduler'),
                              salt['pillar.get']('services:nova_cert'),
                              salt['pillar.get']('services:nova_consoleauth'),
                              salt['pillar.get']('services:nova_novncproxy'),
                              salt['pillar.get']('services:cinder_api'),
                              salt['pillar.get']('services:cinder_scheduler'),
                              salt['pillar.get']('services:neutron_server'),
                              salt['pillar.get']('services:glance_api'),
                              salt['pillar.get']('services:glance_registry') ] %}
{% set services_unavailable = [] %}
{% set all_services_running = False %}
{% for service in openstack_services %}
  {% if salt['service.available']('%s' % service) == False %}
    {% do services_unavailable.append(service) %}
  {% endif %}
{% endfor %}
{% if services_unavailable|length == openstack_services|length %}
        echo "OpenStack services are not yet installed"
        exit 0
{% elif services_unavailable|length > 0 %}
  {% for service in services_unavailable %}
        echo "Service {{ service }} is not installed"
  {% endfor %}
        exit 1
{% else %}
  {% set stopped_services = [] %}
  {% for service in openstack_services %}
    {% if salt['service.status']('%s' % service) == False %}
      {% do stopped_services.append(service) %}
    {% endif %}
  {% endfor %}
  {% if stopped_services|length > 0 %}
    {% for service in stopped_services %}
        echo "Service {{ service }} is not running"
    {% endfor %}
        exit 1
  {% else %}
    {% set all_services_running = True %}
        echo "All OpenStack services are running"
  {% endif %}
{% endif %}

services_check:
  cmd.run:
    - name: "bash /tmp/services_check.sh"
    - require:
      - file: services_check_script

services_check_script_delete:
  file.absent:
    - name: "/tmp/services_check.sh"
    - require:
      - file: services_check_script


# Set up a temporary keystone admin user needed for soft reset state

temporary_admin_script:
  file.managed:
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/temporary_admin_create.sh"
    - contents: |
        #!/bin/bash
        set -e

{% if all_services_running == True %}
        keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" tenant-create --name "{{ temporary_tenant_name }}"
        keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" user-create --name "{{ temporary_admin_name }}" --pass "{{ temporary_admin_password }}"
        keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" user-role-add --user "{{ temporary_admin_name }}" --tenant "{{ temporary_tenant_name }}" --role admin
{% else %}
        echo "OpenStack services are not yet installed"
{% endif %}

    - require:
      - cmd: services_check

temporary_admin:
  cmd.run:
    - name: "bash /tmp/temporary_admin_create.sh"
    - require:
      - file: temporary_admin_script

temporary_admin_script_delete:
  file.absent:
    - name: "/tmp/temporary_admin_create.sh"
    - require:
      - file: temporary_admin_script


heat_reset_script:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/heat_reset.sh"
    - contents: |
        #!/bin/bash
        set -e

{% if all_services_running == True %}
        # Add admin user to all tenants
        MEMBER_ROLE_ID=`keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} role-get _member_ | egrep "\|\s+id\s+\|" | awk '{print $4}'`
        ADMIN_ROLE_ID=`keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} role-get admin | egrep "\|\s+id\s+\|" | awk '{print $4}'`
        TEMP_ADMIN_USER_ID=`keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} user-get {{ temporary_admin_name }} | egrep "\|\s+id\s+\|" | awk '{print $4}'`
        for TENANT_ID in `keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} tenant-list | awk '{print $2}' | grep -E "[0-9a-f]{32}"`; do
            if [ "`keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} user-role-list --user $TEMP_ADMIN_USER_ID --tenant $TENANT_ID | grep $MEMBER_ROLE_ID`" = "" ]; then
                keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} user-role-add --user $TEMP_ADMIN_USER_ID --role $MEMBER_ROLE_ID --tenant $TENANT_ID
            fi
            if [ "`keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} user-role-list --user $TEMP_ADMIN_USER_ID --tenant $TENANT_ID | grep $ADMIN_ROLE_ID`" = "" ]; then
                keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} user-role-add --user $TEMP_ADMIN_USER_ID --role $ADMIN_ROLE_ID --tenant $TENANT_ID
            fi
        done

        # Delete heat stacks from all tenants using admin user
        for TENANT_ID in `keystone --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} tenant-list | awk '{print $2}' | grep -E "[0-9a-f]{32}"`; do
            for HEAT_STACK_ID in `heat --os-username={{ temporary_admin_name }} --os-tenant-id=$TENANT_ID --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} stack-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
                RET=`heat --os-username={{ temporary_admin_name }} --os-tenant-id=$TENANT_ID --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} stack-delete $HEAT_STACK_ID`

                # Check if stack was successfully deleted
                while [ "`heat --os-username={{ temporary_admin_name }} --os-tenant-id=$TENANT_ID --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} stack-list | grep $HEAT_STACK_ID | awk '{print $2}'`" != "" ]; do
                    if [ "`heat --os-username={{ temporary_admin_name }} --os-tenant-id=$TENANT_ID --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} stack-list | grep $HEAT_STACK_ID | awk '{print $6}' | grep FAILED`" != "" ]; then
                        echo "Failed to delete Heat stack $HEAT_STACK_ID"
                        exit 1
                    fi
                    sleep 1
                done

                echo "Heat stack $HEAT_STACK_ID was deleted"
            done
        done
{% else %}
        echo "OpenStack services are not yet installed"
{% endif %}

    - require:
      - cmd: services_check

heat_reset:
  cmd:
    - run
    - name: "bash /tmp/heat_reset.sh"
    - require:
      - file: heat_reset_script

heat_reset_script_delete:
  file:
    - absent
    - name: "/tmp/heat_reset.sh"
    - require:
      - file: heat_reset_script


#   Remove existing nova virtual machines from all tenants

nova_reset_script:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/nova_reset.sh"
    - contents: |
        #!/bin/bash
        set -e

{% if all_services_running == True %}
        ID=`nova --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} list --all-tenants | awk '{if (NR == 4){print $2}}'`
        while [ "$ID" != "" ]; do
            nova --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} delete $ID
            ID_NEW=`nova --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} list --all-tenants | awk '{if (NR == 4){print $2}}'`
            while [ "$ID_NEW" = "$ID" ]; do
                sleep 1
                ID_NEW=`nova --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} list --all-tenants | awk '{if (NR == 4){print $2}}'`
            done
            ID=$ID_NEW
        done
{% else %}
        echo "OpenStack services are not yet installed"
{% endif %}

    - require:
      - cmd: services_check

nova_reset:
  cmd:
    - run
    - name: "bash /tmp/nova_reset.sh"
    - require:
      - file: nova_reset_script

nova_reset_script_delete:
  file:
    - absent
    - name: "/tmp/nova_reset.sh"
    - require:
      - file: nova_reset_script


#   Remove existing cinder volumes from all tenants

cinder_reset_script:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/cinder_reset.sh"
    - contents: |
        #!/bin/bash
        set -e

{% if all_services_running == True %}
        ID=`cinder --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} list --all-tenants | awk '{if (NR == 4){print $2}}'`
        while [ "$ID" != "" ]; do
            cinder --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} force-delete $ID
            while [ "`cinder --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} list --all-tenants | grep $ID`" != "" ]; do
                sleep 1
            done
            ID=`cinder --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} list --all-tenants | awk '{if (NR == 4){print $2}}'`
        done
{% else %}
        echo "OpenStack services are not yet installed"
{% endif %}

    - require:
      - cmd: services_check

cinder_reset:
  cmd:
    - run
    - name: "bash /tmp/cinder_reset.sh"
    - require:
      - file: cinder_reset_script

cinder_reset_script_delete:
  file:
    - absent
    - name: "/tmp/cinder_reset.sh"
    - require:
      - file: cinder_reset_script


#   Remove the following existing items from all tenants:
#    - neutron security groups
#    - floating ips
#    - router gateways
#    - router interfaces
#    - routers
#    - network subnets
#    - networks

neutron_reset_script:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/neutron_reset.sh"
    - contents: |
        #!/bin/bash
        set -e

{% if all_services_running == True %}
        # Delete all security groups
        for i in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} security-group-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} security-group-delete $i
        done

        # Delete all floating IPs
        for i in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} floatingip-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} floatingip-delete $i
        done

        # Clear the gateway from all existing routers
        for i in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} router-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} router-gateway-clear $i
        done

        # Clear all interfaces from all existing routers
        for router in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} router-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            for interface in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} router-port-list $router | awk '{print $8}' | grep -Eo "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
                neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} router-interface-delete $router $interface
            done
        done

        # Delete all routers
        for i in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} router-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} router-delete $i
        done

        # Delete all networks subnets
        for i in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} subnet-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} subnet-delete $i
        done

        # Delete all networks
        for i in `neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} net-list | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            neutron --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} net-delete $i
        done
{% else %}
        echo "OpenStack services are not yet installed"
{% endif %}

    - require:
      - cmd: services_check

neutron_reset:
  cmd:
    - run
    - name: "bash /tmp/neutron_reset.sh"
    - require:
      - file: neutron_reset_script

neutron_reset_script_delete:
  file:
    - absent
    - name: "/tmp/neutron_reset.sh"
    - require:
      - file: neutron_reset_script


#   Remove every uploaded glance image from all tenants

glance_reset_script:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/glance_reset.sh"
    - contents: |
        #!/bin/bash
        set -e

{% if all_services_running == True %}
        for ID in `glance --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} image-list --all-tenants | awk '{print $2}' | grep -E "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}"`; do
            glance --os-username={{ temporary_admin_name }} --os-tenant-name={{ temporary_tenant_name }} --os-password={{ temporary_admin_password }} --os-auth-url={{ keystone_admin_endpoint }} image-delete $ID
        done
{% else %}
        echo "OpenStack services are not yet installed"
{% endif %}

    - require:
      - cmd: services_check

glance_reset:
  cmd:
    - run
    - name: "bash /tmp/glance_reset.sh"
    - require:
      - file: glance_reset_script

glance_reset_script_delete:
  file:
    - absent
    - name: "/tmp/glance_reset.sh"
    - require:
      - file: glance_reset_script


#   Remove the following existing items from keystone: 
#    - services
#    - endpoints
#    - roles
#    - tenants

keystone_reset_script:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/keystone_reset.sh"
    - contents: |
        #!/bin/bash
        set -e

{% if all_services_running == True %}
        ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" service-list | awk '{if (NR == 4){print $2}}'`
        while [ "$ID" != "" ]; do
            keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" service-delete $ID
            ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" service-list | awk '{if (NR == 4){print $2}}'`
        done

        ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" user-list | awk '{if (NR == 4){print $2}}'`
        while [ "$ID" != "" ]; do
            keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" user-delete $ID
            ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" user-list | awk '{if (NR == 4){print $2}}'`
        done

        ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" role-list | grep -v "_member_" | awk '{if (NR == 4){print $2}}'`
        while [ "$ID" != "" ]; do
            keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" role-delete $ID
            ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" role-list | grep -v "_member_" | awk '{if (NR == 4){print $2}}'`
        done

        ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" tenant-list | awk '{if (NR == 4){print $2}}'`
        while [ "$ID" != "" ]; do
            keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" tenant-delete $ID
            ID=`keystone --os-endpoint="{{ keystone_admin_endpoint }}" --os-token="{{ keystone_admin_token }}" tenant-list | awk '{if (NR == 4){print $2}}'`
        done
{% else %}
        echo "OpenStack services are not yet installed"
{% endif %}

    - require:
      - cmd: services_check

keystone_reset:
  cmd:
    - run
    - name: "bash /tmp/keystone_reset.sh"
    - require:
      - file: keystone_reset_script

keystone_reset_script_delete:
  file:
    - absent
    - name: "/tmp/keystone_reset.sh"
    - require:
      - file: keystone_reset_script
