resources:
  system:
    conf:
      series_persist_file: "/etc/salt/.openstack_series.persist"
    packages:
      - "yum-plugin-priorities"
      - "iptables-services"
    repositories:
      epel: "http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm"
      openstack:
        series:
          juno: "http://rdo.fedorapeople.org/openstack-juno/rdo-release-juno.rpm"
          kilo: "http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm"
    repo_packages:
      - "openstack-selinux"
    services:
      network_manager: "NetworkManager"
      network: "network"
      firewalld: "firewalld"
      iptables: "iptables"

  ntp:
    packages:
      - "ntp"
    services:
      ntp: "ntpd"

  mysql:
    dirs:
      - "/etc/my.cnf.d"
      - "/var/lib/mysql"
    conf:
      mysqld: "/etc/my.cnf.d/mysql_openstack.cnf"
    packages:
      - "mariadb"
      - "mariadb-server"
      - "MySQL-python"
    services:
      mysql: "mariadb"

  rabbitmq:
    services:
      rabbitmq: rabbitmq-server
    packages:
      - "rabbitmq-server"

  keystone:
    dirs:
      - "/var/lib/keystone"
      - "/etc/keystone"
    openstack_series:
      kilo:
        conf:
          keystone: "/etc/keystone/keystone.conf"
          httpd: "/etc/httpd/conf/httpd.conf"
        packages:
          - "openstack-keystone"
          - "httpd"
          - "mod_wsgi"
          - "python-openstackclient"
          - "memcached"
          - "python-memcached"
        services:
          keystone: "openstack-keystone"
          memcached: "memcached"
          httpd: "httpd"
        files:
          wsgi_conf: " /etc/httpd/conf.d/wsgi-keystone.conf"
          wsgi_components_url: "http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/kilo"
          www: "/var/www/cgi-bin/keystone"
          sqlite: "/var/lib/keystone/keystone.sqlite"
      juno:
        conf:
          keystone: "/etc/keystone/keystone.conf"
        packages:
          - "openstack-keystone"
          - "python-keystoneclient"
        services:
          keystone: "openstack-keystone"
        files:
          sqlite: "/var/lib/keystone/keystone.sqlite"

  glance:
    dirs:
      - "/var/lib/glance"
      - "/etc/glance"
    openstack_series:
      kilo:
        conf:
          api: "/etc/glance/glance-api.conf"
          registry: "/etc/glance/glance-registry.conf"
        packages:
          - "openstack-glance"
          - "python-glance"
          - "python-glanceclient"
        services:
          api: "openstack-glance-api"
          registry: "openstack-glance-registry"
        files:
          images_dir: "/var/lib/glance/images"
          sqlite: "/var/lib/glance/glance.sqlite"
      juno:
        conf:
          api: "/etc/glance/glance-api.conf"
          registry: "/etc/glance/glance-registry.conf"
        packages:
          - "openstack-glance"
          - "python-glanceclient"
        services:
          api: "openstack-glance-api"
          registry: "openstack-glance-registry"
        files:
          images_dir: "/var/lib/glance/images"
          sqlite: "/var/lib/glance/glance.sqlite"

  nova:
    dirs:
      - "/var/lib/nova"
      - "/etc/nova"
    openstack_series:
      kilo:
        conf:
          nova: "/etc/nova/nova.conf"
        packages:
          controller:
            - "openstack-nova-api"
            - "openstack-nova-cert"
            - "openstack-nova-conductor"
            - "openstack-nova-console"
            - "openstack-nova-novncproxy"
            - "openstack-nova-scheduler"
            - "python-novaclient"
          compute:
            kvm:
              - "sysfsutils"
              - "openstack-nova-compute"
        services:
          controller:
            api: "openstack-nova-api"
            cert: "openstack-nova-cert"
            consoleauth: "openstack-nova-consoleauth"
            scheduler: "openstack-nova-scheduler"
            conductor: "openstack-nova-conductor"
            novncproxy: "openstack-nova-novncproxy"
          compute:
            kvm:
              libvirtd: "libvirtd"
              nova: "openstack-nova-compute"
        files:
          nova_tmp: "/var/lib/nova/tmp"
          sqlite: "/var/lib/nova/nova.sqlite"
      juno:
        conf:
          nova: "/etc/nova/nova.conf"
        packages:
          controller:
            - "openstack-nova-api"
            - "openstack-nova-cert"
            - "openstack-nova-conductor"
            - "openstack-nova-console"
            - "openstack-nova-novncproxy"
            - "openstack-nova-scheduler"
            - "python-novaclient"
          compute:
            kvm:
              - "sysfsutils"
              - "openstack-nova-compute"
        services:
          controller:
            api: "openstack-nova-api"
            cert: "openstack-nova-cert"
            consoleauth: "openstack-nova-consoleauth"
            scheduler: "openstack-nova-scheduler"
            conductor: "openstack-nova-conductor"
            novncproxy: "openstack-nova-novncproxy"
          compute:
            kvm:
              libvirtd: "libvirtd"
              nova: "openstack-nova-compute"
        files:
          sqlite: "/var/lib/nova/nova.sqlite"

  neutron:
    dirs:
      - "/var/lib/neutron"
      - "/etc/neutron"
    openstack_series:
      kilo:
        conf:
          ml2_symlink: "/etc/neutron/plugin.ini"
          neutron: "/etc/neutron/neutron.conf"
          sysctl: "/etc/sysctl.conf"
          ml2: "/etc/neutron/plugins/ml2/ml2_conf.ini"
          l3_agent: "/etc/neutron/l3_agent.ini"
          dhcp_agent: "/etc/neutron/dhcp_agent.ini"
          dnsmasq_config_file: "/etc/neutron/dnsmasq-neutron.conf"
          metadata_agent: "/etc/neutron/metadata_agent.ini"
          ovs_systemd: "/usr/lib/systemd/system/neutron-openvswitch-agent.service"
        packages:
          controller:
            - "openstack-neutron"
            - "openstack-neutron-ml2"
            - "python-neutronclient"
          compute:
            kvm:
              - "openstack-neutron"
              - "openstack-neutron-ml2"
              - "openstack-neutron-openvswitch"
          network:
            - "openstack-neutron"
            - "openstack-neutron-ml2"
            - "openstack-neutron-openvswitch"
        services:
          controller:
            neutron_server: "neutron-server"
          compute:
            kvm:
              ovs: "openvswitch"
              ovs_agent: "neutron-openvswitch-agent"
          network:
            l3_agent: "neutron-l3-agent"
            dhcp_agent: "neutron-dhcp-agent"
            metadata_agent: "neutron-metadata-agent"
            ovs: "openvswitch"
            ovs_agent: "neutron-openvswitch-agent"
            ovs_cleanup: "neutron-ovs-cleanup"
      juno:
        conf:
          ml2_symlink: "/etc/neutron/plugin.ini"
          neutron: "/etc/neutron/neutron.conf"
          sysctl: "/etc/sysctl.conf"
          ml2: "/etc/neutron/plugins/ml2/ml2_conf.ini"
          l3_agent: "/etc/neutron/l3_agent.ini"
          dhcp_agent: "/etc/neutron/dhcp_agent.ini"
          dnsmasq_config_file: "/etc/neutron/dnsmasq-neutron.conf"
          metadata_agent: "/etc/neutron/metadata_agent.ini"
          ovs_systemd: "/usr/lib/systemd/system/neutron-openvswitch-agent.service"
        packages:
          controller:
            - "openstack-neutron"
            - "openstack-neutron-ml2"
            - "python-neutronclient"
          compute:
            kvm:
              - "openstack-neutron"
              - "openstack-neutron-ml2"
              - "openstack-neutron-openvswitch"
          network:
            - "openstack-neutron"
            - "openstack-neutron-ml2"
            - "openstack-neutron-openvswitch"
        services:
          controller:
            neutron_server: "neutron-server"
          compute:
            kvm:
              ovs: "openvswitch"
              ovs_agent: "neutron-openvswitch-agent"
          network:
            l3_agent: "neutron-l3-agent"
            dhcp_agent: "neutron-dhcp-agent"
            metadata_agent: "neutron-metadata-agent"
            ovs: "openvswitch"
            ovs_agent: "neutron-openvswitch-agent"
            ovs_cleanup: "neutron-ovs-cleanup"

  openvswitch:
    conf:
      promisc_interfaces_script: "/var/lib/openvswitch/openstack-promisc-interfaces.sh"
      promisc_interfaces_systemd: "/lib/systemd/system/openstack-promisc-interfaces.service"
      network_scripts: "/etc/sysconfig/network-scripts"

  horizon:
    dirs:
      - "/var/lib/openstack-dashboard"
      - "/etc/openstack-dashboard"
    conf:
      local_settings: "/etc/openstack-dashboard/local_settings"
    packages:
      - "openstack-dashboard"
      - "httpd"
      - "mod_wsgi"
      - "memcached"
      - "python-memcached"
    services:
      httpd: "httpd"
      memcached: "memcached"
    files:
      openstack_dashboard_static: "/usr/share/openstack-dashboard/static"

  cinder:
    dirs:
      - "/var/lib/cinder"
      - "/etc/cinder"
    openstack_series:
      kilo:
        conf:
          cinder: "/etc/cinder/cinder.conf"
          losetup_systemd: "/lib/systemd/system/openstack-losetup.service"
          cinder_conf_dist: "/usr/share/cinder/cinder-dist.conf"
        packages:
          controller:
            - "openstack-cinder"
            - "python-cinderclient"
            - "python-oslo-db"
          storage:
            - "openstack-cinder"
            - "targetcli"
            - "python-oslo-db"
            - "python-oslo-log"
            - "MySQL-python"
        services:
          controller:
            scheduler: "openstack-cinder-scheduler"
            api: "openstack-cinder-api"
          storage:
            target: "target"
            cinder_volume: "openstack-cinder-volume"
            lvm2: "lvm2-lvmetad"
        files:
          lock: "/var/lib/cinder/tmp"
          sqlite: "/var/lib/cinder/cinder.sqlite"
      juno:
        conf:
          cinder: "/etc/cinder/cinder.conf"
          losetup_systemd: "/lib/systemd/system/openstack-losetup.service"
        packages:
          controller:
            - "openstack-cinder"
            - "python-cinderclient"
            - "python-oslo-db"
          storage:
            - "openstack-cinder"
            - "targetcli"
            - "python-oslo-db"
            - "MySQL-python"
        services:
          controller:
            scheduler: "openstack-cinder-scheduler"
            api: "openstack-cinder-api"
          storage:
            target: "target"
            cinder_volume: "openstack-cinder-volume"
            lvm2: "lvm2-lvmetad"
        files:
          sqlite: "/var/lib/cinder/cinder.sqlite"

  heat:
    dirs:
      - "/var/lib/heat"
      - "/etc/heat"
    openstack_series:
      kilo:
        conf:
          heat: "/etc/heat/heat.conf"
          heat_conf_dist: "/usr/share/heat/heat-dist.conf"
        packages:
          - "openstack-heat-api"
          - "openstack-heat-api-cfn"
          - "openstack-heat-engine"
          - "python-heatclient"
        services:
          api: "openstack-heat-api"
          api_cfn: "openstack-heat-api-cfn"
          engine: "openstack-heat-engine"
        files:
          sqlite: "/var/lib/heat/heat.sqlite"
      juno:
        conf:
          heat: "/etc/heat/heat.conf"
        packages:
          - "openstack-heat-api"
          - "openstack-heat-api-cfn"
          - "openstack-heat-engine"
          - "python-heatclient"
        services:
          api: "openstack-heat-api"
          api_cfn: "openstack-heat-api-cfn"
          engine: "openstack-heat-engine"
        files:
          sqlite: "/var/lib/heat/heat.sqlite"
