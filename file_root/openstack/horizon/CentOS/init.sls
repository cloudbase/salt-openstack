{% set horizon = salt['openstack_utils.horizon']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


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
{% for pkg in horizon['packages'] %}
      - pkg: horizon_{{ pkg }}_install
{% endfor %}


horizon_fix_permissions:
  file.directory:
    - name: {{ horizon['files']['openstack_dashboard_static'] }}
    - user: apache
    - group: apache
    - recurse:
        - user
        - group
    - require:
{% for pkg in horizon['packages'] %}
      - pkg: horizon_{{ pkg }}_install
{% endfor %}


horizon_setsebool_on:
  cmd.run:
    - name: setsebool -P httpd_can_network_connect on
    - unless: sestatus | egrep "SELinux\sstatus:\s*disabled"
    - require:
      - file: horizon_local_settings


{% for service in horizon['services'] %}
horizon_{{ service }}_running:
  service.running:
    - enable: True
    - name: {{ horizon['services'][service] }}
    - watch: 
      - file: horizon_local_settings
{% endfor %}
