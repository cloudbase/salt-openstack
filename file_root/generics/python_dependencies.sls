{% if grains['os'] == 'CentOS' %}
python_pip_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:python_pip') }}

six_upgrade:
  cmd:
    - run
    - name: "pip install six -U"
    - require:
      - pkg: python_pip_install
{% endif %}