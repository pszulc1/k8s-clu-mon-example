/*
Use ./setup.jsonnet earlier, see generic / working deployment description in the project README.md

In this example metrics scraping is based on .defaultServiceMonitor and
additional ServiceMonitors defined per monitored application in apps.serviceMonitors

Monitored applications namespaces MUST BE ADDED to grant a Prometheus permissions
to search services in namespaces other than default, kube-system and this environment's namespace.

Sample monitored applications are defined for example purposes in `<this-repo>/sample-apps/`.

ServiceMonitors for `opalcbox` application are created in the namespace of this environment, whereas
for `services` application are created in its own namespace.
Would be better if they were created in the application namespace by the application developers
(i.e. those who have the appropriate knowledge).
In fact ServiceMonitor's namespace doesn't matter as Prometheus Operator do have access to
ServiceMonitors in all namespaces existing in the cluster.

The most straightforward would be if every application in cluster could be scraped by .defaultServiceMonitor only.
However, in case when applications metrics should be selected, a custom ServiceMonitor must be defined.

To obtain vector config files (ie. vector configuration) or particular one use:  

  tk eval environments/kind-my-one/example-one/monitoring.jsonnet | jq '.vector.aggregator.configMap.data|keys'
  tk eval environments/kind-my-one/example-one/monitoring.jsonnet | jq '.vector.aggregator.configMap.data["destination_logs.json"]' | jq 'fromjson'

*/

local debug = (import 'k8s-clu-mon/debug.libsonnet')(std.thisFile, (import 'global.json').debug);

local apps = {
  names:
    ['otherapp']
    + [_app.name for _app in $.custom],
  namespaces:
    ['prod-otherapp']  // concerns 'otherapp', monitored by .defaultServiceMonitor only
    + [_app.namespace for _app in $.custom],  // monitored by $.serviceMonitors and .defaultServiceMonitor
  serviceMonitors: std.flattenArrays([_app.serviceMonitors for _app in $.custom]),

  configsMixin: {

    'apps_transforms.json': {
      transforms:
        {
          apps_routed: {
            type: 'route',
            inputs: ['k8s-clu-mon_logs'],
            reroute_unmatched: true,
            route: {},
          },

          apps_logs: {
            type: 'remap',
            inputs: [
              'apps_routed._unmatched',
              'apps_logs_*',
            ],
            source: '', // or for test purposes:
            /*
            source: |||
              .yyy_kubernetes_logs = %kubernetes_logs
              .yyy_vector = %vector
              ."yyy_k8s-clu-mon" = %"k8s-clu-mon"
            |||,
            */
          },

          apps_metrics: {
            type: 'remap',
            inputs: ['apps_metrics_*'],
            source: '',
          }
        }
        +
        std.foldl(
          function(result, elem) result + elem,
          [_app.logTransforms for _app in $.custom],
          {}
        ),
    },

    'destination_metrics.json'+: { // redefined
      sinks+: {
        prometheus_exporter+: {
          inputs+: ['apps_metrics']
        }
      }
    },

    'destination_logs.json'+: {  // redefined
      sinks+: {
        'loki-instance'+: {
          inputs: ['apps_logs'],
          labels+: {
            extra_label: 'extra_label_value',
          },
        },
      },
    },

  },

  custom: [
    (import 'opalcbox.jsonnet'),
    (import 'services.jsonnet'),
  ],
};


(import 'monitoring.libsonnet')(apps.namespaces, configsMixin=apps.configsMixin, destination='test')
+ { appServiceMonitors: apps.serviceMonitors }

+ debug.new('##0', { names: apps.names, namespaces: apps.namespaces })
+ debug.new('##1', apps.custom)
+ debug.new('##2', apps.configsMixin)
