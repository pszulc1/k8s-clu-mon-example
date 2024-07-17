/*
ServiceMonitors regarding another application in a different namespace.
ServiceMonitors are created in the application namespace.
If logTransforms are defined in components, vector transforms names should be prefixed the same way as in opalcbox.jsonnet
*/


// the same version of definitions as used in k8s-clu-mon:
local serviceMonitor = (import 'k8s-clu-mon/po.libsonnet').monitoring.v1.serviceMonitor;

local debug = (import 'k8s-clu-mon/debug.libsonnet')(std.thisFile, (import 'global.json').debug);

local config = import 'config.libsonnet';
local utils = import 'utils.libsonnet';


local appName = 'services';
local appNamespace = 'prod-services';
local appPrefixedName(name) = utils.prefixedName(appName, name);

local components = [

  {
    name: 'redirect',
    endpoints: [
      {
        interval: '66s',
        port: 'service-port',
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
    matchLabels: {
      'app.kubernetes.io/component': 'broker',
      'app.kubernetes.io/name': $.name,
    },

    logTransforms: {
      apps_routed+: {
        route+: {
          [appPrefixedName($.name)]: 
            '%kubernetes_logs.pod_namespace == ' + '"' + appNamespace + '"'
            + ' && '
            + '%kubernetes_logs.pod_labels.\"app.kubernetes.io/component\" == "broker"'
            + ' && '
            + '%kubernetes_logs.pod_labels.\"app.kubernetes.io/name\" == "redirect"'
            + ' && '
            + '%kubernetes_logs.container_name == "my-redirect"'
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
    + serviceMonitor.metadata.withNamespace($.namespace)  // created in the application namespace
    + serviceMonitor.metadata.withLabels({ 'app.kubernetes.io/component': 'app-service-monitor' } + config.labels)
    + serviceMonitor.spec.namespaceSelector.withMatchNames([$.namespace])
    + serviceMonitor.spec.withJobLabel('app.kubernetes.io/name')
    + serviceMonitor.spec.withPodTargetLabels(
      [
        'app.kubernetes.io/component',
        'app.kubernetes.io/name',
        'app.kubernetes.io/part-of',
        'app.kubernetes.io/version',
      ]
    )
    + serviceMonitor.spec.selector.withMatchLabels({ 'app.kubernetes.io/part-of': $.name })
  ,

  serviceMonitors:
    [
      commonServiceMonitor
      + serviceMonitor.metadata.withName(_component.name)
      + serviceMonitor.metadata.withLabelsMixin({ 'app.kubernetes.io/name': _component.name })
      + serviceMonitor.spec.withEndpoints(_component.endpoints)
      + serviceMonitor.spec.selector.withMatchLabelsMixin(_component.matchLabels)

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
