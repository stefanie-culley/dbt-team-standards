{#
    Use the configured schema name exactly as written (bronze, silver, gold),
    so queries are the same in every environment. dbt's default would prefix it
    with the target schema (e.g. dev_silver). Environments are separated by
    catalog instead, set through DBT_CATALOG.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
