{% set system = salt['openstack_utils.system']() %}
{% set yum_repository = salt['openstack_utils.yum_repository']() %}


{% for pkg in system['packages'] %}
system_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}


system_network_manager_dead:
  service.dead:
    - name: {{ system['services']['network_manager'] }}
    - enable: False
    - require:
{% for pkg in system['packages'] %}
      - pkg: system_{{ pkg }}_install
{% endfor %}


system_network_running:
  service.running:
    - name: {{ system['services']['network'] }}
    - enable: True
    - require:
      - service: system_network_manager_dead


system_firewalld_dead:
  service.dead:
    - name: {{ system['services']['firewalld'] }}
    - enable: False
    - require:
{% for pkg in system['packages'] %}
      - pkg: system_{{ pkg }}_install
{% endfor %}


system_iptables_running:
  service.running:
    - name: {{ system['services']['iptables'] }}
    - enable: True
    - require:
      - service: system_firewalld_dead


{% for repo in yum_repository['repositories'] %}
system_repository_{{ repo }}_repo_install:
  cmd.run:
    - name: rpm -ivh {{ yum_repository['repositories'][repo]['url'] }}
    - unless: rpm -qi {{ yum_repository['repositories'][repo]['name'] }}
    - require:
  {% for pkg in system['packages'] %}
      - pkg: system_{{ pkg }}_install
  {% endfor %}
{% endfor %}


{% for pkg in yum_repository['packages'] %}
system_repository_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
    - require:
  {% for repo in yum_repository['repositories'] %}
      - cmd: system_repository_{{ repo }}_repo_install
  {% endfor %}
{% endfor %}
