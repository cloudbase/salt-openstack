{% set yum_repository = salt['openstack_utils.yum_repository']() %}


{% set repo_name = yum_repository['repositories']['openstack']['name_persist'] %}
hard_reset_clean_yum_openstack:
  cmd.run:
    - name: rpm -e {{ repo_name }}
    - onlyif: rpm -qi {{ repo_name }}
