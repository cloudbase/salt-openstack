apache_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:apache', default='apache2') }}
    - require: 
      - pkg: memcached_install

apache_wsgi_module_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:apache_wsgi_module', default='libapache2-mod-wsgi') }}
    - require: 
      - pkg: apache_install

memcached_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:memcached', default='memcached') }}

openstack_dashboard_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:dashboard', default='openstack-dashboard') }}
    - require: 
      - pkg: apache_install

enable_dashboard: 
  file: 
    - symlink
    - force: true
    - name: "{{ salt['pillar.get']('conf_files:apache_dashboard_enabled_conf', default='/etc/apache2/conf-enabled/openstack-dashboard.conf') }}"
    - target: "{{ salt['pillar.get']('conf_files:apache_dashboard_conf', default='/etc/apache2/conf-available/openstack-dashboard.conf') }}"
    - require: 
      - pkg: openstack_dashboard_install

openstack_dashboard_ubuntu_theme_purge: 
  pkg:
    - purged
    - name: openstack-dashboard-ubuntu-theme
    - require: 
      - pkg: openstack_dashboard_install

memcached_service_running:
  service: 
    - running
    - name: {{ salt['pillar.get']('services:memcached', default='memcached') }}
    - watch: 
      - pkg: memcached_install

apache_service:
  service: 
    - running
    - name: {{ salt['pillar.get']('services:apache', default='apache2') }}
    - watch: 
      - pkg: apache_wsgi_module_install
      - file: enable_dashboard
      - service: memcached_service_running

