/*
There are 2 ServiceMonitors defined, one for a specific component, the other for a group of components.
As they all relate to services from the same application, they have common parts.
ServiceMonitors are created in the config.namespace namespace.

ServiceMonitors' name is prefixed to distinguish ServiceMonitors from various applications created 
in the same config.namespace namespace.
Vector transforms names are prefixed as well.
*/


// the same version of definitions as used in k8s-clu-mon:
local serviceMonitor = (import 'k8s-clu-mon/po.libsonnet').monitoring.v1.serviceMonitor;

local debug = (import 'k8s-clu-mon/debug.libsonnet')(std.thisFile, (import 'global.json').debug);

local config = import 'config.libsonnet';
local utils = import 'utils.libsonnet';


local appName = 'opalcbox';
local appNamespace = 'prod-opalcbox';
local appPrefixedName(name) = utils.prefixedName(appName, name);

local components = [

  {
    name: 'opalcbox-pl',
    endpoints: [
      {
        interval: '35s',
        port: 'web',
        metricRelabelings: [
          {
            // dropping selected metrics (example)
            sourceLabels: ['__name__'],
            regex: 'nginx_connections_(.+)',
            action: 'drop',
          },
          {
            // dropping selected metrics (example)
            sourceLabels: ['__name__'],
            regex: 'go_(.+)',
            action: 'drop',
          },
        ],
      },
    ],
    matchLabels: {
      component: 'web-server',
      opal: $.name,
    },

    logTransforms: {

      apps_routed+: {
        route+: {
          [appPrefixedName($.name)]: 
            '%kubernetes_logs.pod_namespace == ' + '"' + appNamespace + '"'
            + ' && '
            + '%kubernetes_logs.pod_labels.app == "opalcbox"'
            + ' && '
            + '%kubernetes_logs.pod_labels.component == "web-server"'
            + ' && '
            + '%kubernetes_logs.pod_labels.opal == "opalcbox-pl"'
            + ' && '
            + '%kubernetes_logs.container_name == "nginx"'
          ,
        },
      },

      ['apps_logs_' + appPrefixedName($.name)]: {
        type: 'remap',
        inputs: ['apps_routed.' + appPrefixedName($.name)],
        source: '. = parse_nginx_log!(.payload,"combined")',
      },

      // log to metric example for this application component, meaningless metric
      ['apps_filtered_' + appPrefixedName($.name) + '_status200']: {
        type: 'filter',
        inputs: ['apps_logs_' + appPrefixedName($.name)],
        condition: '.status == 200',
      },
      ['apps_metrics_' + appPrefixedName($.name) + '_status200']: {
        type: 'log_to_metric',
        inputs: ['apps_filtered_' + appPrefixedName($.name) + '_status200'],
        metrics: [
          {
            type: 'counter',
            field: 'status',
            // name & namespace must comply with the metric name/label format
            name: 'status200_total',
            namespace: utils.metricLabelName(appPrefixedName($.name)),  // note: contains application and componnet name
            // additional tags, basic set is inherited from vector-aggregator,
            // ie. place where metrics are scraped from
            tags: {
              log_namespace: '{{%kubernetes_logs.pod_namespace}}',
              log_component: '{{%kubernetes_logs.pod_labels.component}}',
              log_container: '{{%kubernetes_logs.container_name}}',
            },
          }
        ],
      }

    },

  },

  {
    name: 'uke-ftps',  // for all uke-ftps-* components
    endpoints: [
      {
        interval: '44s',
        port: 'api',
        metricRelabelings: [
          {
            // dropping selected metrics (example)
            sourceLabels: ['__name__'],
            regex: 'go_(.+)',
            action: 'drop',
          },
        ],
      },
    ],
    matchLabels: { component: $.name },

    logTransforms: {
      apps_routed+: {
        route+: {
          [appPrefixedName($.name)]:
            '%kubernetes_logs.pod_namespace == ' + '"' + appNamespace + '"'
            + '&&'
            + '%kubernetes_logs.pod_labels.app == "opalcbox"'
            + '&&'
            + '%kubernetes_logs.pod_labels.component == "uke-ftps"'
            + '&&'
            + '%kubernetes_logs.container_name == "ftps-server"'
          ,
        },
      },
      ['apps_logs_' + appPrefixedName($.name)]: {
        type: 'remap',
        inputs: ['apps_routed.' + appPrefixedName($.name)],
        source: '', // fake here
      },
    },

  },

];

{
  name: appName,
  namespace: appNamespace,

  local commonServiceMonitor =
    serviceMonitor.new('mock')
    + serviceMonitor.metadata.withNamespace(config.namespace) // created in a common monitoring namespace
    + serviceMonitor.metadata.withLabels({ 'app.kubernetes.io/component': 'app-service-monitor' } + config.labels)
    + serviceMonitor.spec.withJobLabel('opal')
    + serviceMonitor.spec.withPodTargetLabels(['app', 'component', 'opal'])
    + serviceMonitor.spec.namespaceSelector.withMatchNames([$.namespace])
    + serviceMonitor.spec.selector.withMatchLabels({ app: $.name })
  ,

  serviceMonitors:
    [
      local serviceMonitorName = appPrefixedName(_component.name);

      commonServiceMonitor
      + serviceMonitor.metadata.withName(serviceMonitorName)
      + serviceMonitor.metadata.withLabelsMixin({ 'app.kubernetes.io/name': serviceMonitorName })
      + serviceMonitor.spec.selector.withMatchLabelsMixin(_component.matchLabels)
      + serviceMonitor.spec.withEndpoints(
        [
          _endpoint
          {
            relabelings: [
              {
                // prefixing job name with application name
                sourceLabels: ['job'],
                regex: '(.+)',
                replacement: appPrefixedName('') + '${1}',
                targetLabel: 'job',
                action: 'replace',
              },
            ],
          }
          for _endpoint in _component.endpoints
        ]
      )
      for _component in components
    ],

  logTransforms:
    std.foldl(
      function(result, elem) result + elem,
      [_component.logTransforms for _component in components],
      {}
    ),
}
+ {
    [if debug.on then '__debugMock']:
      {}
      + debug.new('##0', config)
      + debug.new(
        '##1',
        {
          name: $.name,
          namespace: $.namespace,
          components: [_component.name for _component in components],
        }
      )
      + debug.new('##2', components)
      + debug.new('##3', $.logTransforms)
}
