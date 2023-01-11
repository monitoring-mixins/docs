.PHONY: prometheus_alerts.yaml prometheus_rules.yaml dashboards_out

prometheus_alerts.yaml: mixin.libsonnet
	@mkdir -p out/
	mixtool generate alerts -a out/prometheus_alerts.yaml -y $<

prometheus_rules.yaml: mixin.libsonnet
	@mkdir -p out/
	mixtool generate rules -r out/prometheus_rules.yaml -y $<

dashboards_out: mixin.libsonnet
	@mkdir -p out/dashboards
	mixtool generate dashboards -d out/dashboards $<

all: mixin.libsonnet
	@mkdir -p out/
	mixtool generate all -d out/dashboards -r out/prometheus_rules.yaml -a out/prometheus_alerts.yaml -y  $<