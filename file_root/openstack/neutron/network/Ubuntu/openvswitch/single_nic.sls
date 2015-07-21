{% set neutron = salt['openstack_utils.neutron']() %}
{% set openvswitch = salt['openstack_utils.openvswitch']() %}


openvswitch_interfaces_promisc_upstart_job:
  file.managed:
    - name: {{ openvswitch['conf']['promisc_interfaces'] }}
    - user: root
    - group: root
    - mode: 644
    - contents: |

        start on runlevel [2345]

        script
            #!/usr/bin/env bash
            ip link set br-proxy up promisc on
{% for bridge in neutron['bridges'] %}
  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
            ip link add proxy-veth-{{ bridge }} type veth peer name veth-{{ bridge }}-br-proxy
            ip link set veth-{{ bridge }}-br-proxy up promisc on
            ip link set proxy-veth-{{ bridge }} up promisc on
  {% endif %}
{% endfor %}
        end script
    - require:
{% for bridge in neutron['bridges'] %}
  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
      - cmd: openvswitch_proxy-veth-{{ bridge }}_up
      - cmd: openvswitch_veth-{{ bridge }}-br-proxy_up
  {% endif %}
{% endfor %}


openvswitch_br-proxy_network_interface:
  cmd.run:
    - name: sed -i "s/{{ neutron['single_nic']['interface'] }}/br-proxy/" {{ openvswitch['conf']['interfaces'] }}
    - unless: egrep "br-proxy" "{{ openvswitch['conf']['interfaces'] }}"
    - require:
      - file: openvswitch_interfaces_promisc_upstart_job


openvswitch_{{ openvswitch['conf']['interfaces'] }}_network_interface:
  file.append:
    - name: "{{ openvswitch['conf']['interfaces'] }}"
    - unless: egrep "{{ neutron['single_nic']['interface'] }}" "{{ openvswitch['conf']['interfaces'] }}"
    - text: |

        auto {{ neutron['single_nic']['interface'] }}
        iface {{ neutron['single_nic']['interface'] }} inet manual
        up ifconfig $IFACE 0.0.0.0 up
        up ip link set $IFACE promisc on
        down ip link set $IFACE promisc off
        down ifconfig $IFACE down

    - require:
      - cmd: openvswitch_br-proxy_network_interface


openvswitch_br-proxy_script_create:
  file.managed:
    - name: {{ neutron['single_nic']['set_up_script'] }}
    - user: root
    - group: root
    - mode: 755
    - contents: |
        #!/usr/bin/env bash
        set -e

        # This script should be executed at the end of the salt states execution
        # to set up the br-proxy used for the current single NIC OpenStack deployment.

        ifdown {{ neutron['single_nic']['interface'] }} && ifup {{ neutron['single_nic']['interface'] }}
        ifup br-proxy
        if [ "`ovs-vsctl list-ports br-proxy | grep {{ neutron['single_nic']['interface'] }}`" = "" ]; then
            ovs-vsctl add-port br-proxy {{ neutron['single_nic']['interface'] }}
        else
            echo "{{ neutron['single_nic']['interface'] }} was already added to br-proxy"
        fi
    - require:
      - file: openvswitch_{{ openvswitch['conf']['interfaces'] }}_network_interface
