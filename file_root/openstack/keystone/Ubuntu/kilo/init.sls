{% set keystone = salt['openstack_utils.keystone']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


keystone_conf:
  ini.options_present:
    - name: {{ keystone['conf']['keystone'] }}
    - sections:
        DEFAULT:
          admin_token: {{ keystone['admin_token'] }}
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
        database:
          connection: "mysql://{{ keystone['database']['username'] }}:{{ keystone['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ keystone['database']['db_name'] }}"
        memcache:
          servers: "localhost:11211"
        token:
          provider: "keystone.token.providers.uuid.Provider"
          driver: "keystone.token.persistence.backends.memcache.Token"
        revoke:
          driver: "keystone.contrib.revoke.backends.sql.Revoke"
    - require:
{% for pkg in keystone['packages'] %}
      - pkg: keystone_{{ pkg }}_install
{% endfor %}


keystone_db_sync:
  cmd.run:
    - name: su -s /bin/sh -c "keystone-manage db_sync" keystone
    - require:
      - ini: keystone_conf


keystone_www_dir:
  file.directory:
    - name: {{ keystone['files']['www'] }}
    - user: keystone
    - group: keystone
    - mode: 755
    - makedirs: True
    - require:
      - cmd: keystone_db_sync


keystone_virtual_host_conf:
  file.managed:
    - name: {{ keystone['files']['wsgi_available'] }}
    - contents: |
        Listen 5000
        Listen 35357

        <VirtualHost *:5000>
            WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone display-name=%{GROUP}
            WSGIProcessGroup keystone-public
            WSGIScriptAlias / {{ keystone['files']['www'] }}/main
            WSGIApplicationGroup %{GLOBAL}
            WSGIPassAuthorization On
            <IfVersion >= 2.4>
              ErrorLogFormat "%{cu}t %M"
            </IfVersion>
            LogLevel info
            ErrorLog ${APACHE_LOG_DIR}/keystone-error.log
            CustomLog ${APACHE_LOG_DIR}/keystone-access.log combined
        </VirtualHost>

        <VirtualHost *:35357>
            WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone display-name=%{GROUP}
            WSGIProcessGroup keystone-admin
            WSGIScriptAlias / {{ keystone['files']['www'] }}/admin
            WSGIApplicationGroup %{GLOBAL}
            WSGIPassAuthorization On
            <IfVersion >= 2.4>
              ErrorLogFormat "%{cu}t %M"
            </IfVersion>
            LogLevel info
            ErrorLog ${APACHE_LOG_DIR}/keystone-error.log
            CustomLog ${APACHE_LOG_DIR}/keystone-access.log combined
        </VirtualHost>
    - require: 
      - file: keystone_www_dir


keystone_apache2_servername:
  file.append:
    - name: {{ keystone['conf']['apache2'] }}
    - text:
      - "ServerName {{ openstack_parameters['controller_ip'] }}"
    - unless: >
        cat {{ keystone['conf']['httpd'] }} | egrep -v "^\s*#" | grep ServerName
    - require:
      - file: keystone_virtual_host_conf


keystone_apache2_wsgi_enable:
  cmd.run:
    - name: a2enmod wsgi
    - require:
      - file: keystone_apache2_servername


keystone_virtual_host_enable:
  file.symlink:
    - name: {{ keystone['files']['wsgi_enabled'] }}
    - target: {{ keystone['files']['wsgi_available'] }}
    - require:
      - cmd: keystone_apache2_wsgi_enable


keystone_wsgi_components:
  cmd.run:
    - name: "curl {{ keystone['files']['wsgi_components_url'] }} | tee {{ keystone['files']['www'] }}/main {{ keystone['files']['www'] }}/admin"
    - require: 
      - file: keystone_virtual_host_enable


keystone_wsgi_dir_permissions:
  file.directory:
    - name: {{ keystone['files']['www'] }}
    - user: keystone
    - group: keystone
    - mode: 755
    - recurse:
      - user
      - group
      - mode
    - require:
      - cmd: keystone_wsgi_components


keystone_service_dead:
  service.dead:
    - enable: False
    - name: {{ keystone['services']['keystone'] }}
    - require:
      - ini: keystone_conf


keystone_service_apache2_running:
  service.running:
    - enable: True
    - name: {{ keystone['services']['apache'] }}
    - require:
      - file: keystone_wsgi_dir_permissions
      - service: keystone_service_dead
    - watch:
      - file: keystone_virtual_host_conf
      - file: keystone_apache2_servername


keystone_sqlite_delete:
  file.absent:
    - name: {{ keystone['files']['sqlite'] }}
    - require:
      - cmd: keystone_db_sync


keystone_wait:
  cmd.run:
    - name: sleep 5
    - require:
      - service: keystone_service_apache2_running
      - service: keystone_service_dead
