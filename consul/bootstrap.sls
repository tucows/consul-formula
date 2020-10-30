{% if not salt['grains.get']('bootstrap') %}

{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot + '/map.bootstrap.jinja' import consulbootstrap with context -%}
{%- set tenant_name = salt['pillar.get']('tenant_name') -%}

bootstrap-config:
  file.serialize:
    - name: /etc/consul.d/config.json
    - encoding: utf-8
    - formatter: json
    - dataset: {{ consulbootstrap.config | json }}
    - user: {{ consulbootstrap.user }}
    - group: {{ consulbootstrap.group }}
    - mode: '0640'
    {%- if consulbootstrap.service %}
    - watch_in:
       - service: consul
    {%- endif %}

bootstrap-service:
  service.running:
    - name: consul
    - enable: True

bootstrap-out-dir:
  file.directory:
    - name: /etc/consul.d/outputs/
    - mode: '0640'

{% for file in salt['cp.list_master'](prefix=tplroot ~'/files/policies', saltenv=tenant_name) %}
bootstrap-file-{{ file }}:
  file.managed:
    - name: /etc/consul.d/policies/{{ file }}
    - makedirs: True
    - source: salt://{{ file }}
{% endfor %}

{% for file in salt['cp.list_master'](prefix=tplroot ~'/files/tokens', saltenv=tenant_name) %}
bootstrap-file-{{ file }}:
  file.managed:
    - name: /etc/consul.d/tokens/{{ file }}
    - makedirs: True
    - source: salt://{{ tplroot }}/files/tokens/{{ file }}
{% endfor %}

{% for file in salt['cp.list_master'](prefix=tplroot ~'/files/policies', saltenv=tenant_name) %}
bootstrap-query-{{ file }}:
  http.query:
    - name: "https://{{ salt['grains.get']('primary_ipaddress') }}//v1/acl/policies"
    - port: 8501
    - ca_bundle: /etc/consul.d/certs/ca.crt
    - method: PUT
    - headers: True
    - header_list: 'X-Consul-Token: {{ consulbootstrap.master_token }}'
    - text_out="/etc/consul.d/outputs/{{ file }}.out"
    - data_file: /etc/consul.d/policies/{{ file }}
    - status: 200
{% endfor %}

{% for file in salt['cp.list_master'](prefix=tplroot ~'/files/tokens', saltenv=tenant_name) %}
bootstrap-query-{{ file }}:
  http.query:
    - name: "https://{{ salt['grains.get']('primary_ipaddress') }}//v1/acl/token"
    - port: 8501
    - ca_bundle: /etc/consul.d/certs/ca.crt
    - method: PUT
    - headers: True
    - header_list: 'X-Consul-Token: {{ consulbootstrap.master_token }}'
    - data_file: /etc/consul.d/tokens/{{ file }}
    - text_out="/etc/consul.d/outputs/{{ file }}.out"
    - status: 200
{% endfor %}

{% endif %}
