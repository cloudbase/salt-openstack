{% from "cluster/resources.jinja" import formulas with context %}

openstack:
  "*":
{% for formula in formulas %}
    - {{ formula }}
{% endfor %}
