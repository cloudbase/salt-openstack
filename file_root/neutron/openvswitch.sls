{% from "cluster/resources.jinja" import get_candidate with context %}
{% from "cluster/physical_networks.jinja" import bridges with context %}

{% if grains['os'] == 'Ubuntu' %}
neutron_l2_agent_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_l2_agent') }}"
{% if bridges %}
    - require: 
{% set count = 1 %}
{% for bridge in bridges %}
      - cmd: bridge_{{ bridge }}_{{ count }}_create
{% set count = count + 1 %}
{% endfor %}
{% endif %}

neutron_common_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_common') }}"
{% endif %}

openvswitch_switch_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:openvswitch') }}"

l2_agent_neutron_config_file: 
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron') }}"
    - group: neutron
    - user: neutron
    - mode: 644
    - require: 
      - ini: l2_agent_neutron_config_file
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron') }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
{% if pillar['cluster_type'] == 'icehouse' and salt['pillar.get']('queue_engine') == 'rabbit' %}
          rpc_backend: "neutron.openstack.common.rpc.impl_kombu"
{% else %}
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
{% endif %}
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
        keystone_authtoken: 
{% if pillar['cluster_type'] == 'juno' %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          identity_uri: http://{{ get_candidate('keystone') }}:35357
{% else %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_protocol: http
          auth_port: 35357
{% endif %}
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
{% if grains['os'] == 'Ubuntu' %}
    - require: 
      - pkg: neutron_l2_agent_install
{% endif %}

{% if salt['pillar.get']('neutron:single_nic:enable').lower() == "true" %}
bridge_br-proxy_create: 
  cmd: 
    - run
    - name: "ovs-vsctl add-br br-proxy"
    - unless: "ovs-vsctl br-exists br-proxy"
    - require: 
      - service: openvswitch_switch_running

bridge_br-proxy_bring_up: 
  cmd: 
    - run
    - name: "ip link set br-proxy promisc on"
    - require: 
      - cmd: bridge_br-proxy_create
{% endif %}

{% set count = 1 %}
{% for bridge in bridges %}
bridge_{{ bridge }}_{{ count }}_create: 
  cmd: 
    - run
    - name: "ovs-vsctl add-br {{ bridge }}"
    - unless: "ovs-vsctl br-exists {{ bridge }}"
    - require: 
      - service: openvswitch_switch_running

{% if salt['pillar.get']('neutron:single_nic:enable').lower() == "true" %}
{% if bridge not in [ salt['pillar.get']('neutron:integration_bridge', default='br-int'), 
                      salt['pillar.get']('neutron:tunneling:tunnel_bridge', default='br-tun') ] %}
{{ bridge }}_{{ count }}_veth_create:
  cmd:
    - run
    - name: "ip link add proxy-veth{{ count }} type veth peer name veth{{ count }}-br-proxy"
    - unless: "ip link list | egrep proxy-veth{{ count }}"
    - require:
      - cmd: bridge_br-proxy_bring_up
      - cmd: bridge_{{ bridge }}_{{ count }}_create

{{ bridge }}_{{ count }}_veth_add:
  cmd:
    - run
    - name: "ovs-vsctl add-port {{ bridge }} veth{{ count }}-br-proxy"
    - unless: "ovs-vsctl list-ports {{ bridge }} | grep veth{{ count }}-br-proxy"
    - require:
      - cmd: {{ bridge }}_{{ count }}_veth_create

{{ bridge }}_{{ count }}_br-proxy_veth_add:
  cmd:
    - run
    - name: "ovs-vsctl add-port br-proxy proxy-veth{{ count }}"
    - unless: "ovs-vsctl list-ports br-proxy | grep proxy-veth{{ count }}"
    - require:
      - cmd: {{ bridge }}_{{ count }}_veth_create

{{ bridge }}_{{ count }}_veth_bring_up:
  cmd:
    - run
    - name: "ip link set veth{{ count }}-br-proxy up promisc on"
    - require:
      - cmd: {{ bridge }}_{{ count }}_veth_add

{{ bridge }}_{{ count }}_br-proxy_veth_bring_up:
  cmd:
    - run
    - name: "ip link set proxy-veth{{ count }} up promisc on"
    - require:
      - cmd: {{ bridge }}_{{ count }}_br-proxy_veth_add
{% endif %}
{% else %}
{% if bridges[bridge] != None and bridges[bridge] != "" %}
{{ bridge }}_{{ count }}_interface_add:
  cmd:
    - run
    - name: "ovs-vsctl add-port {{ bridge }} {{ bridges[bridge] }}"
    - unless: "ovs-vsctl list-ports {{ bridge }} | grep {{ bridges[bridge] }}"
    - require: 
      - cmd: "bridge_{{ bridge }}_{{ count }}_create"
{{ bridges[bridge] }}_{{ count }}_interface_bring_up:
  cmd:
    - run
    - name: "ip link set {{ bridges[bridge] }} up promisc on"
    - require:
      - cmd: {{ bridge }}_{{ count }}_interface_add
{% endif %}
{% endif %}
{% set count = count + 1 %}
{% endfor %}

{% if grains['os'] == 'Ubuntu' %}
promisc_interfaces_upstart_job:
  file: 
    - managed
    - name: {{ salt['pillar.get']('conf_files:openstack_promisc_interfaces') }}
    - user: root
    - group: root
    - mode: 644
    - contents: |

        start on runlevel [2345]

        script
{% if salt['pillar.get']('neutron:single_nic:enable').lower() == "true" %}
            ip link set br-proxy up promisc on
{% set count = 1 %}
{% for bridge in bridges %}
{% if bridge not in [ salt['pillar.get']('neutron:integration_bridge', default='br-int'), 
                      salt['pillar.get']('neutron:tunneling:tunnel_bridge', default='br-tun') ] %}
            ip link add proxy-veth{{ count }} type veth peer name veth{{ count }}-br-proxy
            ip link set veth{{ count }}-br-proxy up promisc on
            ip link set proxy-veth{{ count }} up promisc on
{% endif %}
{% set count = count + 1 %}
{% endfor %}
{% else %}
{% for bridge in bridges %}
{% if bridges[bridge] != None and bridges[bridge] != "" %}
            ip link set {{ bridges[bridge] }} up promisc on
{% endif %}
{% endfor %}
{% endif %}
        end script

{% if salt['pillar.get']('neutron:single_nic:enable').lower() == "true" %}
br-proxy_network_interface:
  cmd:
    - run
    - name: sed -i "s/{{ salt['pillar.get']('neutron:single_nic:interface') }}/br-proxy/" /etc/network/interfaces
    - unless: egrep "br-proxy" "/etc/network/interfaces"

{{ salt['pillar.get']('neutron:single_nic:interface') }}_network_interface:
  file:
    - append
    - name: "/etc/network/interfaces"
    - unless: egrep "{{ salt['pillar.get']('neutron:single_nic:interface') }}" "/etc/network/interfaces"
    - text: |

        auto {{ salt['pillar.get']('neutron:single_nic:interface') }}
        iface {{ salt['pillar.get']('neutron:single_nic:interface') }} inet manual
        up ifconfig $IFACE 0.0.0.0 up
        up ip link set $IFACE promisc on
        down ip link set $IFACE promisc off
        down ifconfig $IFACE down

    - require:
      - cmd: br-proxy_network_interface

br-proxy_script:
  file: 
    - managed
    - name: {{ salt['pillar.get']('conf_files:br_proxy_script') }}
    - user: root
    - group: root
    - mode: 755
    - contents: |
        set -e

        # This script should be executed at the end of the salt scripts execution
        # to set up the br-proxy used for the current single NIC OpenStack deployment.

        ifdown {{ salt['pillar.get']('neutron:single_nic:interface') }} && ifup {{ salt['pillar.get']('neutron:single_nic:interface') }}
        ifup br-proxy
        if [ "`ovs-vsctl list-ports br-proxy | grep {{ salt['pillar.get']('neutron:single_nic:interface') }}`" = "" ]; then
            ovs-vsctl add-port br-proxy {{ salt['pillar.get']('neutron:single_nic:interface') }}
        else
            echo "{{ salt['pillar.get']('neutron:single_nic:interface') }} was already added to br-proxy"
        fi

{% endif %}

{% elif grains['os'] == 'CentOS' %}
{% if grains['osrelease_info'][0] == 7 %}
openstack_promisc_interfaces_script:
  file: 
    - managed
    - name: {{ salt['pillar.get']('conf_files:openstack_promisc_interfaces') }}
    - user: root
    - group: root
    - mode: 755
    - contents: |
        #!/bin/sh
{% if salt['pillar.get']('neutron:single_nic:enable').lower() == "true" %}
        ip link set br-proxy up promisc on
        ip link set {{ salt['pillar.get']('neutron:single_nic:interface') }} up promisc on
{% set count = 1 %}
{% for bridge in bridges %}
{% if bridge not in [ salt['pillar.get']('neutron:integration_bridge', default='br-int'), 
                      salt['pillar.get']('neutron:tunneling:tunnel_bridge', default='br-tun') ] %}
        ip link add proxy-veth{{ count }} type veth peer name veth{{ count }}-br-proxy
        ip link set veth{{ count }}-br-proxy up promisc on
        ip link set proxy-veth{{ count }} up promisc on
{% endif %}
{% set count = count + 1 %}
{% endfor %}
{% else %}
{% set count = 1 %}
{% for bridge in bridges %}
{% if bridge not in [ salt['pillar.get']('neutron:integration_bridge', default='br-int'), 
                      salt['pillar.get']('neutron:tunneling:tunnel_bridge', default='br-tun') ] %}
{% if bridges[bridge] != None and bridges[bridge] != "" %}
        ip link set {{ bridges[bridge] }} up promisc on
{% endif %}
{% endif %}
{% set count = count + 1 %}
{% endfor %}
{% endif %}

openstack_promisc_interfaces_systemd_service:
  file:
    - managed
    - name: {{ salt['pillar.get']('conf_files:openstack_promisc_interfaces_systemd') }}
    - user: root
    - group: root
    - mode: 644
    - require:
      - ini: openstack_promisc_interfaces_systemd_service
  ini:
    - options_present
    - name: {{ salt['pillar.get']('conf_files:openstack_promisc_interfaces_systemd') }}
    - sections:
        Unit:
          Description: "Set openvswitch ports in promisc mode"
          After: "network.target"
        Service:
          Type: "oneshot"
          ExecStart: "{{ salt['pillar.get']('conf_files:openstack_promisc_interfaces') }}"
        Install:
          WantedBy: "default.target"
    - require:
      - file: openstack_promisc_interfaces_script

openstack_promisc_interfaces_enable:
  service:
    - enabled
    - name: "{{ salt['pillar.get']('services:openstack_promisc_interfaces') }}"
    - require:
      - file: openstack_promisc_interfaces_systemd_service

{% if salt['pillar.get']('neutron:single_nic:enable').lower() == "true" %}
{% if not salt['file.file_exists']("/etc/sysconfig/network-scripts/ifcfg-br-proxy") %}
br-proxy_ovs_bridge_network_script: 
  file: 
    - managed
    - name: "/etc/sysconfig/network-scripts/ifcfg-br-proxy"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE=br-proxy
        DEVICETYPE=ovs
        TYPE=OVSBridge
{% set bootproto = salt['ini.get_option']('/etc/sysconfig/network-scripts/ifcfg-%s' % salt['pillar.get']('neutron:single_nic:interface'), 'DEFAULT_IMPLICIT', 'BOOTPROTO') %}
        BOOTPROTO={{ bootproto }}
        ONBOOT=yes
{% if bootproto.lower() == 'static' or bootproto.lower() == '"static"' or bootproto.lower() == "'static'" %}
        IPADDR={{ salt['ini.get_option']('/etc/sysconfig/network-scripts/ifcfg-%s' % salt['pillar.get']('neutron:single_nic:interface'), 'DEFAULT_IMPLICIT', 'IPADDR') }}
        NETMASK={{ salt['ini.get_option']('/etc/sysconfig/network-scripts/ifcfg-%s' % salt['pillar.get']('neutron:single_nic:interface'), 'DEFAULT_IMPLICIT', 'NETMASK') }}
{% set gateway = salt['ini.get_option']('/etc/sysconfig/network-scripts/ifcfg-%s' % salt['pillar.get']('neutron:single_nic:interface'), 'DEFAULT_IMPLICIT', 'GATEWAY') %}
{% if gateway %}
        GATEWAY={{ gateway }}
{% endif %}
{% set dns1 = salt['ini.get_option']('/etc/sysconfig/network-scripts/ifcfg-%s' % salt['pillar.get']('neutron:single_nic:interface'), 'DEFAULT_IMPLICIT', 'DNS1') %}
{% if dns1 %}
        DNS1={{ dns1 }}
{% endif %}
{% set dns2 = salt['ini.get_option']('/etc/sysconfig/network-scripts/ifcfg-%s' % salt['pillar.get']('neutron:single_nic:interface'), 'DEFAULT_IMPLICIT', 'DNS2') %}
{% if dns2 %}
        DNS2={{ dns2 }}
{% endif %}
{% endif %}

{{ salt['pillar.get']('neutron:single_nic:interface') }}_ovs_port_network_script:
  file:
    - managed
    - name: "/etc/sysconfig/network-scripts/ifcfg-{{ salt['pillar.get']('neutron:single_nic:interface') }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE={{ salt['pillar.get']('neutron:single_nic:interface') }}
        ONBOOT=yes
        HWADDR={{ grains['hwaddr_interfaces'][salt['pillar.get']('neutron:single_nic:interface')] }}
        TYPE=OVSPort
        DEVICETYPE=ovs
        OVS_BRIDGE=br-proxy
        ONBOOT=yes
        NOZEROCONF=yes
{% endif %}

{% set count = 1 %}
{% for bridge in bridges %}
{% if bridge not in [ salt['pillar.get']('neutron:integration_bridge', default='br-int'), 
                      salt['pillar.get']('neutron:tunneling:tunnel_bridge', default='br-tun') ] %}
proxy-veth{{ count }}_ovs_port_network_script:
  file:
    - managed
    - name: "/etc/sysconfig/network-scripts/ifcfg-proxy-veth{{ count }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE=proxy-veth{{ count }}
        ONBOOT=yes
        TYPE=OVSPort
        DEVICETYPE=ovs
        OVS_BRIDGE=br-proxy
        ONBOOT=yes
        NOZEROCONF=yes
{% endif %}
{% set count = count + 1 %}
{% endfor %}

{{ salt['pillar.get']('neutron:single_nic:interface') }}_ovs_port_promisc_mode:
  cmd:
    - run
    - name: "ip link set {{ salt['pillar.get']('neutron:single_nic:interface') }} up promisc on"

{% else %}

{% for bridge in bridges %}
{% if bridge not in [ salt['pillar.get']('neutron:integration_bridge', default='br-int'), 
                      salt['pillar.get']('neutron:tunneling:tunnel_bridge', default='br-tun') ] %}

{{ bridge }}_ovs_bridge_network_script:
  file:
    - managed
    - name: "/etc/sysconfig/network-scripts/ifcfg-{{ bridge }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE={{ bridge }}
        DEVICETYPE=ovs
        TYPE=OVSBridge
        BOOTPROTO=none
        ONBOOT=yes
        NOZEROCONF=yes

{% if bridges[bridge] != None and bridges[bridge] != "" %}

{{ bridges[bridge] }}_ovs_port_network_script:
  file:
    - managed
    - name: "/etc/sysconfig/network-scripts/ifcfg-{{ bridges[bridge] }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE={{ bridges[bridge] }}
        ONBOOT=yes
        TYPE=OVSPort
        DEVICETYPE=ovs
        OVS_BRIDGE={{ bridge }}
        ONBOOT=yes
        NOZEROCONF=yes
        BOOTPROTO=none
    - require:
      - file: {{ bridge }}_ovs_bridge_network_script

{% endif %}
{% endif %}
{% endfor %}
{% endif %}
{% endif %}
{% endif %}

{% if pillar['cluster_type'] == 'juno' and grains['os'] == 'CentOS' %}
enable_neutron_plugin: 
  file: 
    - symlink
    - force: true
    - name: "{{ salt['pillar.get']('conf_files:neutron_plugin_ini') }}"
    - target: "{{ salt['pillar.get']('conf_files:neutron_ml2') }}"
    - require: 
      - file: l2_agent_neutron_config_file

openvswitch_fix:
  cmd:
    - run
    - name: |
        set -e
        cp /usr/lib/systemd/system/neutron-openvswitch-agent.service /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
        sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service
{% endif %}

openvswitch_switch_running:
  service: 
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:openvswitch') }}"
    - require: 
      - pkg: openvswitch_switch_install
{% if grains['os'] == 'Ubuntu' %}
      - pkg: neutron_common_install
{% endif %}

neutron_l2_agent_running:
  service: 
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:neutron_l2_agent') }}"
{% if grains['os'] == 'Ubuntu' %}
    - require: 
      - pkg: neutron_l2_agent_install
{% endif %}
    - watch: 
      - file: l2_agent_neutron_config_file
      - ini: l2_agent_neutron_config_file

{% if pillar['cluster_type'] == 'juno' and grains['os'] == 'CentOS' %}
neutron_ovs_cleanup_service_enabled:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:ovs_cleanup_service') }}"
    - require:
      - pkg: openvswitch_switch_install
{% if grains['os'] == 'Ubuntu' %}
      - pkg: neutron_l2_agent_install
{% endif %}
{% endif %}

neutron_ovs_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: openvswitch_switch_running
      - service: neutron_l2_agent_running
