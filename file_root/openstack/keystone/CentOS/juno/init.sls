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
        token:
          provider: "keystone.token.providers.uuid.Provider"
          driver: "keystone.token.persistence.backends.sql.Token"
        revoke:
          driver: "keystone.contrib.revoke.backends.sql.Revoke"
    - require:
{% for pkg in keystone['packages'] %}
      - pkg: keystone_{{ pkg }}_install
{% endfor %}


keystone_pki_setup:
  cmd.run:
    - name: |
        keystone-manage pki_setup --keystone-user keystone --keystone-group keystone && \
        chown -R keystone:keystone /var/log/keystone && \
        chown -R keystone:keystone /etc/keystone/ssl && \
        chmod -R o-rwx /etc/keystone/ssl
    - require:
      - ini: keystone_conf


keystone_db_sync:
  cmd.run:
    - name: su -s /bin/sh -c "keystone-manage db_sync" keystone
    - require:
      - cmd: keystone_pki_setup


keystone_service_running:
  service.running:
    - enable: True
    - name: {{ keystone['services']['keystone'] }}
    - require:
      - cmd: keystone_db_sync
    - watch:
      - ini: keystone_conf


keystone_sqlite_delete:
  file.absent:
    - name: {{ keystone['files']['sqlite'] }}
    - require:
      - cmd: keystone_db_sync


keystone_wait:
  cmd.run:
    - name: sleep 5
    - require:
      - service: keystone_service_running
