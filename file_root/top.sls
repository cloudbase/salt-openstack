{% from "cluster/resources.jinja" import formulas with context %}

openstack:
  "*":
    - generics.*
{% for formula in formulas %}
    - {{ formula }}
{% endfor %}
    - postinstall
    - postinstall.files
