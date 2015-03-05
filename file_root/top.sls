{% from "cluster/resources.jinja" import formulas with context %}

openstack:
  "*":
    - generics.headers
    - generics.python_dependencies
    - generics.repositories
    - generics.system_update
    - generics.openstack_packages
{% for formula in formulas %}
    - {{ formula }}
{% endfor %}
    - postinstall.files
