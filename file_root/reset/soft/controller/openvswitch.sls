{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}
{% set neutron = salt['openstack_utils.neutron']() %}


# Delete all OVS bridges created in the previous OpenStack deployment

{% set ovs_service_available = salt['service.available'](neutron['services']['network']['ovs']) %}
{% set single_nic_enable = salt['openstack_utils.boolean_value'](neutron['single_nic']['enable']) %}
openvswitch_bridges_cleanup_script:
  file.managed:
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/openvswitch_bridges_cleanup.sh"
    - contents: |
        #!/bin/bash
        set -e

        OPENVSWITCH="{{ ovs_service_available }}"
        if [ $OPENVSWITCH != "True" ]; then
            echo "OpenvSwitch service is not installed."
            exit 0
        fi

        OPENVSWITCH="{{ ovs_service_available }}"
        if [ $OPENVSWITCH == "True" ]; then
{% if single_nic_enable %}
            for i in `ovs-vsctl show | grep Bridge | awk '{print $2}' | grep -v br-proxy`; do
{% else %}
            for i in `ovs-vsctl show | grep Bridge | awk '{print $2}'`; do 
{% endif %}
                BRIDGE=`echo $i | sed -r "s/^\"(.*)\"$/\1/g"`
                ovs-vsctl del-br $BRIDGE
{% if single_nic_enable %}
            for PROXY_PORT in `ovs-vsctl list-ifaces br-proxy | egrep "proxy-veth[0-9]+"`; do
                ovs-vsctl del-port $PROXY_PORT
            done
{% endif %}
            done
        else
            echo "OpenvSwitch service is not running."
            exit 1
        fi
        exit 0

    - require:
      - cmd: services_check

openvswitch_bridges_cleanup:
  cmd.run:
    - name: "bash /tmp/openvswitch_bridges_cleanup.sh"
    - require:
      - file: openvswitch_bridges_cleanup_script

openvswitch_bridges_cleanup_delete:
  file.absent:
    - name: "/tmp/openvswitch_bridges_cleanup.sh"
    - require:
      - file: openvswitch_bridges_cleanup_script


# Single NIC scenario
# Delete virtual cables' network scripts from previous OpenStack deployment

{% if single_nic_enable %}
  {% if grains['os'] == 'CentOS' %}
centos_veths_network_scripts_delete:
  cmd.run:
    - name: |
        for i in `ls /etc/sysconfig/network-scripts/`; do 
            if [ "`echo $i | egrep 'ifcfg-proxy-veth[0-9]+'`" != "" ]; then 
                rm "/etc/sysconfig/network-scripts/$i"
            fi
        done
    - require:
      - cmd: openvswitch_bridges_cleanup
  {% endif %}
{% endif %}


