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

{% set count = 1 %}
{% for bridge in bridges %}
bridge_{{ bridge }}_{{ count }}_create: 
  cmd: 
    - run
    - name: "ovs-vsctl add-br {{ bridge }}"
    - unless: "ovs-vsctl br-exists {{ bridge }}"
    - require: 
      - service: openvswitch_switch_running
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
{% set count = count + 1 %}
{% endfor %}

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
