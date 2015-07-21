{% set horizon = salt['openstack_utils.horizon']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


horizon_ubuntu_theme_purge:
  pkg.purged:
    - name: {{ horizon['conf']['ubuntu_theme'] }}
    - require:
{% for pkg in horizon['packages'] %}
      - pkg: horizon_{{ pkg }}_install
{% endfor %}


horizon_apache2_conf:
  file.managed:
    - name: {{ horizon['conf']['apache2'] }}
    - user: root
    - group: root
    - mode: 644
    - contents: |
        WSGIScriptAlias /dashboard /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi
        WSGIDaemonProcess horizon user=horizon group=horizon processes=3 threads=10
        WSGIProcessGroup horizon
        Alias /static /usr/share/openstack-dashboard/openstack_dashboard/static/
        Alias /horizon/static /usr/share/openstack-dashboard/openstack_dashboard/static/
        <Directory /usr/share/openstack-dashboard/openstack_dashboard/wsgi>
          Order allow,deny
          Allow from all
        </Directory>
    - require:
      - pkg: horizon_ubuntu_theme_purge


horizon_local_settings:
  file.managed:
    - source: salt://openstack/horizon/local_settings.py
    - name: {{ horizon['conf']['local_settings'] }}
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        controller_ip: "{{ openstack_parameters['controller_ip'] }}"
    - require:
      - file: horizon_apache2_conf


horizon_memcached_running:
  service.running:
    - enable: True
    - name: {{ horizon['services']['memcached'] }}
    - watch: 
      - file: horizon_local_settings
      - file: horizon_apache2_conf


horizon_apache_running:
  service.running:
    - enable: True
    - name: {{ horizon['services']['apache'] }}
    - watch: 
      - file: horizon_local_settings
      - file: horizon_apache2_conf
    - require:
      - service: horizon_memcached_running
