{% from "cluster/resources.jinja" import get_candidate with context %}

keystone_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:keystone') }}

python_keystone_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:python_keystone') }}

keystone_conf:
    file: 
      - managed
      - name: {{ salt['pillar.get']('conf_files:keystone') }}
      - user: root
      - group: root
      - mode: 644
      - require: 
        - ini: keystone_conf
    ini: 
      - options_present
      - name: {{ salt['pillar.get']('conf_files:keystone') }}
      - sections: 
          DEFAULT: 
            log_dir: "/var/log/keystone"
            admin_token: {{ salt['pillar.get']('keystone:admin_token') }}
          database: 
            connection: mysql://{{ salt['pillar.get']('databases:keystone:username') }}:{{ salt['pillar.get']('databases:keystone:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:keystone:db_name') }}
{% if pillar['cluster_type'] == 'juno' %}
          token: 
            provider: keystone.token.providers.uuid.Provider
            driver: keystone.token.persistence.backends.sql.Token
{% endif %}
      - require: 
        - pkg: keystone_install
        - pkg: python_keystone_install

keystone_sqlite_delete: 
  file: 
    - absent
    - name: /var/lib/keystone/keystone.sqlite
    - require: 
      - file: keystone_conf

{% if pillar['cluster_type'] == 'juno' and grains['os'] == 'CentOS' %}
keystone_pki_setup: 
  cmd: 
    - run
    - name: |
        set -e
        keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
        chown -R keystone:keystone /var/log/keystone
        chown -R keystone:keystone /etc/keystone/ssl
        chmod -R o-rwx /etc/keystone/ssl
{% endif %}

keystone_db_sync: 
  cmd: 
    - run
    - name: "su -s /bin/sh -c 'keystone-manage db_sync' keystone"
    - require: 
      - file: keystone_sqlite_delete

keystone_service_running:
  service: 
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:keystone') }}
    - require: 
      - pkg: keystone_install
      - pkg: python_keystone_install
    - watch: 
      - file: keystone_conf
      - ini: keystone_conf
      - cmd: keystone_db_sync

keystone_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: keystone_service_running
