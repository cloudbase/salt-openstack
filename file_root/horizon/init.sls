apache_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:apache') }}
    - require: 
      - pkg: memcached_install

apache_wsgi_module_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:apache_wsgi_module') }}
    - require: 
      - pkg: apache_install

memcached_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:memcached') }}

{% if grains['os'] == 'CentOS' %}
python_memcached_install: 
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:python_memcached') }}
    - require:
      - pkg: memcached_install
{% endif %}

openstack_dashboard_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:dashboard') }}
    - require: 
      - pkg: apache_install

{% if grains['os'] == 'Ubuntu' %}
enable_dashboard: 
  file: 
    - symlink
    - force: true
    - name: "{{ salt['pillar.get']('conf_files:apache_dashboard_enabled_conf') }}"
    - target: "{{ salt['pillar.get']('conf_files:apache_dashboard_conf') }}"
    - require: 
      - pkg: openstack_dashboard_install

openstack_dashboard_ubuntu_theme_purge: 
  pkg:
    - purged
    - name: openstack-dashboard-ubuntu-theme
    - require: 
      - pkg: openstack_dashboard_install
{% endif %}

{% if grains['os'] == 'CentOS' %}
setsebool_cmd:
  cmd:
    - run
    - name: setsebool -P httpd_can_network_connect on
    - unless: sestatus | egrep "SELinux\sstatus:\s*disabled"
    - require:
      - pkg: apache_install

{% if grains['osrelease_info'][0] == 7 %}
openstack_dashboard_chown:
  cmd:
    - run
    - name: chown -R apache:apache /usr/share/openstack-dashboard/static
    - require:
      - pkg: openstack_dashboard_install

enable_memcached:
  cmd:
    - run
    - name: >
        sed -i "s/'django.core.cache.backends.locmem.LocMemCache'/'django.core.cache.backends.memcached.MemcachedCache',\n        'LOCATION': '127.0.0.1:11211'/" {{ salt['pillar.get']('conf_files:openstack_dashboard') }}
    - onlyif: egrep "'django.core.cache.backends.locmem.LocMemCache'" {{ salt['pillar.get']('conf_files:openstack_dashboard') }}
    - require:
      - pkg: openstack_dashboard_install

allow_dashboard_connections:
  cmd:
    - run
    - name: sed -i "s/ALLOWED_HOSTS = \[.*\]/ALLOWED_HOSTS = ['*']/" {{ salt['pillar.get']('conf_files:openstack_dashboard') }}
    - unless: egrep "ALLOWED_HOSTS = \['\*'\]" {{ salt['pillar.get']('conf_files:openstack_dashboard') }}
    - require:
      - pkg: openstack_dashboard_install

enable_firewall_http_access:
  cmd:
    - run
    - name: |
        set -e
        firewall-cmd --zone=public --add-service=http --permanent
        firewall-cmd --reload
    - unless: firewall-cmd --zone=public --list-services | grep http
    - require:
      - pkg: openstack_dashboard_install
{% endif %}
{% endif %}

memcached_service_running:
  service: 
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:memcached') }}
    - watch: 
      - pkg: memcached_install

apache_service:
  service: 
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:apache') }}
    - watch: 
      - pkg: apache_wsgi_module_install
      - service: memcached_service_running

