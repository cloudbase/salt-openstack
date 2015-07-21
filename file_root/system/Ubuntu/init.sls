{% set apt_repository = salt['openstack_utils.apt_repository']() %}


{% for pkg in apt_repository['packages'] %}
system_repository_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}


system_repository_openstack_repo_absent:
  file.absent:
    - name: {{ apt_repository['path'] }}


{% if apt_repository['deb_repo'] %}
system_repository_openstack_repo_create:
  file.managed:
    - name: {{ apt_repository['path'] }}
    - contents: {{ apt_repository['deb_repo'] }}
    - require:
      - file: system_repository_openstack_repo_absent
{% endif %}
