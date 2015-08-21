{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


include:
  - system.{{ grains['os'] }}
{% if salt['openstack_utils.boolean_value'](openstack_parameters['system_upgrade']) %}
  - system.upgrade
{% endif %}


openstack_series_persisted:
  file.managed:
    - name: "{{ openstack_parameters['series_persist_file'] }}"
    - user: root
    - group: root
    - mode: 600
    - contents: "{{ openstack_parameters['series'] }}"
