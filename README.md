# Prometheus Monitoring Mixins

> NOTE: This project is *beta* stage.

A mixin is a set of Grafana dashboards and Prometheus rules and alerts, packaged together in a reuseable and extensible bundle.
Mixins are written in [jsonnet](https://jsonnet.org/), and are typically installed and updated with [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler).

For more information about mixins, see:
* [Prometheus Monitoring Mixins Design Doc](https://docs.google.com/document/d/1A9xvzwqnFVSOZ5fD3blKODXfsat5fg6ZhnKu9LK3lB4/view). A [cached pdf](design.pdf) is included in this repo.
* For more motivation, see
"[The RED Method: How to instrument your services](https://kccncna17.sched.com/event/CU8K/the-red-method-how-to-instrument-your-services-b-tom-wilkie-kausal?iframe=no&w=100%&sidebar=yes&bg=no)" talk from CloudNativeCon Austin 2018.  The KLUMPs system demo'd became the basis for the kubernetes-mixin.
* "[Prometheus Monitoring Mixins: Using Jsonnet to Package Together Dashboards, Alerts and Exporters](https://www.youtube.com/watch?v=b7-DtFfsL6E)" talk from CloudNativeCon Copenhagen 2018.
* "[Prometheus Monitoring Mixins: Using Jsonnet to Package Together Dashboards, Alerts and Exporters](https://promcon.io/2018-munich/talks/prometheus-monitoring-mixins/)" talk from PromCon 2018 (slightly updated).

## Mixin creation guidelines

Mixins follow a standard structure, which is enforced by the [mixtool CLI](https://github.com/monitoring-mixins/mixtool).

The schema defines 4 root jsonnet objects to keep Grafana dashboards, Prometheus alerts and rules, and configuration parameters to be applied on the fly when building the mixin.

```
.
├── grafanaDashboards::
├── prometheusAlerts::
│   ├── groups:
├── prometheusRules::
│   ├── groups:
├── _config::
```

This is the expected structure of a mixin jsonnet object definition. The actual recommended file structure has a `mixin.libsonnet` file as root, like the following.

```
.
├── mixin.libsonnet
├── dashboards
│   ├── dashboards.libsonnet
│   │   ├── grafanaDashboards::
├── alerts
│   ├── alerts.libsonnet
│   │   ├── prometheusAlerts::
├── rules
│   ├── rules.libsonnet
│   │   ├── prometheusRules::
``` 

Please note that all the 3 jsonnet objects are made hidden/private (indicated by the trailing ::). 
This is the expected standard to be used with mixtool CLI.
If you want to use pure jsonnet commands against the mixin, please make those objects public.

The mixin.libsonnet file imports all the files described on the previous section, packaging up the mixin. 
It may also contain some changes to the original files, whenever needed. 
These can be defined in itself or importing another jsonnet definition file that changes any of the 4 objects of the structure.

```json
(import 'dashboards/dashboards.libsonnet') +
(import 'alerts/alerts.libsonnet') +
(import 'rules/rules.libsonnet')
(import 'config.libsonnet') +
```

## How to use mixins.

Mixins are designed to be vendored into the repo with your infrastructure config.
To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

You then have three options for deploying your dashboards
1. Generate the config files and deploy them yourself.
2. Use kube-prometheus to deploy this mixin.
3. Use Grizzly to deploy this mixin

## Generate config files

You can manually generate the alerts, dashboards and rules files, but first you
must install some tools. Make sure you're using golang v1.17 or higher, and run:

```
go install github.com/monitoring-mixins/mixtool/cmd/mixtool@master
```

Then, grab the mixin and its dependencies:

```
$ git clone https://github.com/<mixin org>/<mixin repo>
$ cd <mixin repo>
$ jb install
```

Finally, build the mixin with the self contained Makefile, that can be copied from the one present in this repo:

```
$ make prometheus_alerts.yaml
$ make prometheus_rules.yaml
$ make dashboards_out
$ make all
```

All files are generated inside an `out` folder. 
The `prometheus_alerts.yaml` and `prometheus_rules.yaml` file then need to passed
to your Prometheus server, and the files in `out/dashboards` need to be imported
into you Grafana server.  The exact details will depending on how you deploy your
monitoring stack to Kubernetes.

## Using kube-prometheus

See the kube-prometheus docs for [instructions on how to use mixins with kube-prometheus](https://github.com/coreos/kube-prometheus#kube-prometheus).

## Using Grizzly

See the grizzly docs for [instructions on how to use mixins with grizzly](https://grafana.github.io/grizzly/hidden-elements/)

Grizzly support for monitoring-mixin standard is deprecated, but you can use [this adapter](https://github.com/grafana/jsonnet-libs/tree/master/grizzly) to make it work on newer versions of Grizlly.

## Customising the mixin

Mixins typically allows you to override the selectors used for various jobs,
to match those used in your Prometheus set.

This example uses the [kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin).
In a new directory, add a file `mixin.libsonnet`:

```
local kubernetes = import "kubernetes-mixin/mixin.libsonnet";

kubernetes {
  _config+:: {
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    cadvisorSelector: 'job="kubernetes-cadvisor"',
    nodeExporterSelector: 'job="kubernetes-node-exporter"',
    kubeletSelector: 'job="kubernetes-kubelet"',
  },
}
```

Then, install the kubernetes-mixin:

```
$ jb init
$ jb install github.com/kubernetes-monitoring/kubernetes-mixin
```

Generate the alerts, rules and dashboards:

```
$ jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts)' > alerts.yml
$ jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusRules)' > files/rules.yml
$ jsonnet -J vendor -m files/dashboards -e '(import "mixin.libsonnet").grafanaDashboards'
```

## Guidelines for alert names, labels, and annotations

Prometheus alerts deliberately allow users to define their own schema for
names, labels, and annotations. The following is a style guide recommended for
alerts in monitoring mixins. Following this guide helps creating useful
notification templates for all mixins and customizing mixin alerts in a unified
fashion.

The alert **name** is a terse description of the alerting condition, using
camel case, without whitespace, starting with a capital letter. The first
component of the name should be shared between all alerts of a mixin (or
between a group of related alerts within a larger mixin). Examples:
`NodeFilesystemAlmostOutOfFiles` (from the [node-exporter
mixin](https://github.com/prometheus/node_exporter/tree/master/docs/node-mixin),
`PrometheusNotificationQueueRunningFull` (from the [Prometheus
mixin](https://github.com/prometheus/prometheus/blob/master/documentation/prometheus-mixin)).

To mark the severity of an alert, use a **label** called `severity` with one of
the following label values:
- `critical` for alerts that require immediate action. For a production system,
  those alerts will usually hit a pager.
- `warning` for alerts that require action eventually but not urgently enough
  to wake someone up or require them to immediately interrupt what they are
  working on. A typical routing target for those alerts is some kind of ticket
  queueing or bug tracking system.
- `info` for alerts that do not require any action by itself but mark something
  as “out of the ordinary”. Those alerts aren't usually routed anywhere, but
  can be inspected during troubleshooting.
  
An alert can have the following **annotations**:
- `summary` (mandatory): Essentially a more comprehensive and readable version
  of the alert name. Use a human-readable sentence, starting with a capital
  letter and ending with a period. Use a static string or, if dynamic expansion
  is needed, aim for expanding into the same string for alerts that are
  typically grouped together into one notification. In that way, it can be used
  as a common “headline” for all alerts in the notification template. Examples:
  `Filesystem has less than 3% inodes left.` (for the
  `NodeFilesystemAlmostOutOfFiles` alert mentioned above), `Prometheus alert
  notification queue predicted to run full in less than 30m.` (for the
  `PrometheusNotificationQueueRunningFull` alert mentioned above).
- `description` (mandatory): A detailed description of a single alert, with
  most of the important information templated in. The description usually
  expands into a different string for every individual alert within a
  notification. A notification template can iterate through all the
  descriptions and format them into a list. Examples (again corresponding to
  the examples above): `Filesystem on {{ $labels.device }} at {{
  $labels.instance }} has only {{ printf "%.2f" $value }}% available inodes
  left.`, `Alert notification queue of Prometheus %(prometheusName)s is running
  full.`.
  
Note that we plan to add recommended optional annotations for a runbook link
(presumably called `runbook_url`) and a dashboard link
(`dashboard_url`). However, we still need to work out how to configure patterns
for those URLs across mixins in a useful way.
