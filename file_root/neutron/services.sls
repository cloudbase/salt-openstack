{% from "cluster/resources.jinja" import get_candidate with context %}

enable_forwarding: 
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:syslinux', default='/etc/sysctl.conf' ) }}"
    - user: root
    - group: root
    - mode: 644
    - require:
      - ini: enable_forwarding
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:syslinux', default='/etc/sysctl.conf' ) }}"
    - sections: 
        DEFAULT_IMPLICIT: 
          net.ipv4.conf.all.rp_filter: 0
          net.ipv4.ip_forward: 1
          net.ipv4.conf.default.rp_filter: 0

sysctl_cmd:
  cmd.run:
    - name: 'sysctl -p'
    - require:
      - file: enable_forwarding

neutron_l3_agent_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_l3_agent', default='neutron-l3-agent') }}"

neutron_dhcp_agent_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_dhcp_agent', default='neutron-dhcp-agent') }}"

neutron_metadata_agent_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_metadata_agent', default='neutron-metadata-agent') }}"

conntrack_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:conntrack', default='conntrack') }}"

neutron_conf:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron', default='/etc/neutron/neutron.conf') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require: 
      - ini: neutron_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron', default='/etc/neutron/neutron.conf') }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          rpc_backend: neutron.openstack.common.rpc.impl_kombu
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
          core_plugin: neutron.plugins.ml2.plugin.Ml2Plugin
          service_plugins: neutron.services.l3_router.l3_router_plugin.L3RouterPlugin
          allow_overlapping_ips: True
          verbose: True
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_protocol: http
          auth_port: 35357
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
    - require:
      - pkg: neutron_metadata_agent_install
      - pkg: neutron_dhcp_agent_install
      - pkg: neutron_l3_agent_install
      - pkg: conntrack_install

neutron_l3_agent_conf:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron_l3_agent', default='/etc/neutron/l3_agent.ini') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require: 
      - ini: neutron_l3_agent_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron_l3_agent', default='/etc/neutron/l3_agent.ini') }}"
    - sections: 
        DEFAULT: 
          interface_driver: neutron.agent.linux.interface.OVSInterfaceDriver
          use_namespaces: True
          verbose: True
    - require: 
      - pkg: neutron_l3_agent_install

neutron_dhcp_agent_conf:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron_dhcp_agent', default='/etc/neutron/dhcp_agent.ini') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require: 
      - ini: neutron_dhcp_agent_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron_dhcp_agent', default='/etc/neutron/dhcp_agent.ini') }}"
    - sections: 
        DEFAULT: 
          interface_driver: neutron.agent.linux.interface.OVSInterfaceDriver
          dhcp_driver: neutron.agent.linux.dhcp.Dnsmasq
          use_namespaces: True
          dnsmasq_config_file: "/etc/neutron/dnsmasq-neutron.conf"
          verbose: True
    - require: 
      - pkg: neutron_dhcp_agent_install

neutron_dnsmasq_conf:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron_dnsmasq', default='/etc/neutron/dnsmasq-neutron.conf') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require: 
      - ini: neutron_dnsmasq_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron_dnsmasq', default='/etc/neutron/dnsmasq-neutron.conf') }}"
    - sections: 
        DEFAULT_IMPLICIT: 
          dhcp-option-force: "26,1454"
    - require: 
      - file: neutron_dhcp_agent_conf

neutron_metadata_agent_conf:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron_metadata_agent', default='/etc/neutron/metadata_agent.ini') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require: 
      - ini: neutron_metadata_agent_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron_metadata_agent', default='/etc/neutron/metadata_agent.ini') }}"
    - sections: 
        DEFAULT: 
          auth_url: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          auth_region: RegionOne
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
          nova_metadata_ip: "{{ get_candidate('nova') }}"
          metadata_proxy_shared_secret: "{{ salt['pillar.get']('neutron:metadata_secret') }}"
          verbose: True
    - require: 
      - pkg: neutron_metadata_agent_install

neutron_l3_agent_running:
  service: 
    - running
    - name: "{{ salt['pillar.get']('services:neutron_l3_agent', default='neutron-l3-agent') }}"
    - require: 
      - pkg: neutron_l3_agent_install
    - watch: 
      - file: neutron_l3_agent_conf
      - ini: neutron_l3_agent_conf

neutron_dhcp_agent_running:
  service: 
    - running
    - name: "{{ salt['pillar.get']('services:neutron_dhcp_agent', default='neutron-dhcp-agent') }}"
    - require: 
      - pkg: neutron_dhcp_agent_install
    - watch: 
      - file: neutron_dhcp_agent_conf
      - ini: neutron_dhcp_agent_conf

neutron_metadata_agent_running:
  service: 
    - running
    - name: "{{ salt['pillar.get']('services:neutron_metadata_agent', default='neutron-metadata-agent') }}"
    - require: 
      - pkg: neutron_metadata_agent_install
    - watch: 
      - file: neutron_metadata_agent_conf
      - ini: neutron_metadata_agent_conf

neutron_services_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: neutron_l3_agent_running
      - service: neutron_dhcp_agent_running
      - service: neutron_metadata_agent_running
