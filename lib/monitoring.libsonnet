/*
Example of using the k8s-clu-mon jsonnet library.

Metrics are sent to Grafana Cloud using basic authorization.
Some metrics are dropped while scraping, some at remote write.

There is a test mode available where metrics and logs are sent to local instances of Prometheus and Loki appropriately.
It helps to tune metrics and logs before sending them to central monitoring system.

Parametres:
  monitoredNamespaces - namespaces of monitored applications,
  configsMixin - vector config file(s) to be merged with those created in the library,
  destination - destination of metrics and logs, valid values: 'prod' (Grafana Cloud), 'test' (local instances)

Default values are available, see code below.
*/

local k = import 'k.libsonnet';
local secret = k.core.v1.secret;

local kcm = import 'k8s-clu-mon/main.libsonnet';
local debug = (import 'k8s-clu-mon/debug.libsonnet')(std.thisFile, (import 'global.json').debug);

local config = import 'config.libsonnet';


local dests = {

  prometheusDestName:: 'prometheus-instance',
  lokiDestName:: 'loki-instance',

  local baseSecret = 
    secret.new(name='mock', data={}, type='Opaque')
    + secret.metadata.withNamespace(config.namespace)
    + secret.metadata.withLabels(config.labels)
  ,

  test:
    (import 'k8s-clu-mon/test-instances/destinations.libsonnet')
    + {
      prometheus+: {
        local this = self,
        name: $.prometheusDestName,
        secret: { // fake secret
          name: this.name,
          instance:
            baseSecret
            + secret.metadata.withName(this.secret.name)
            + secret.metadata.withLabelsMixin({ 'app.kubernetes.io/name': this.secret.name }),
        },
      },
      loki+: {
        local this = self,
        name: $.lokiDestName,
        secret: { // fake secret
          name: this.name,
          instance:
            baseSecret
            + secret.metadata.withName(this.secret.name)
            + secret.metadata.withLabelsMixin({ 'app.kubernetes.io/name': this.secret.name }),
        },
        // redefines k8s-clu-mon's 'destination_logs.json' vector config file
        // ie. k8s-clu-mon/test-instances/destinations.libsonnet does this
      },
    }
  ,

  prod: {

    prometheus: {
      local this = self,
      local secretData = import 'grafana-cloud-prom-secret.json',

      name: $.prometheusDestName,

      secret: {
        name: this.name,
        url: 'PROM_URL',
        path: 'PROM_PATH',
        username: 'PROM_USERNAME',
        password: 'PROM_PASSWORD',
        instance:
          baseSecret
          + secret.metadata.withName(this.secret.name)
          + secret.metadata.withLabelsMixin({ 'app.kubernetes.io/name': this.secret.name })
          + secret.withData(
            {
              [this.secret.url]: std.base64(std.toString(secretData.url)),
              [this.secret.path]: std.base64(std.toString(secretData.path)),
              [this.secret.username]: std.base64(std.toString(secretData.username)),
              [this.secret.password]: std.base64(std.toString(secretData.password)),
            }
          ),
      },

      remoteWrite: {
        name: this.name,
        url: secretData.url + secretData.path,
        basicAuth: {
          username: {
            key: this.secret.username,
            name: this.secret.name,
            optional: false,
          },
          password: {
            key: this.secret.password,
            name: this.secret.name,
            optional: false,
          },
        },
        writeRelabelConfigs: [
          {
            // Example metric output tuning
            // 'job' label is taken from serviceMonitor.spec.jobLabel or name of Kubernetes Service selected by serviceMonitor
            sourceLabels: ['job', '__name__'],
            regex: 'kubelet;process_max_fds|kubelet;process_open_fds',
            action: 'drop',
          },
        ],

      },
    },

    loki: {
      local this = self,
      local secretData = import 'grafana-cloud-loki-secret.json',

      name: $.lokiDestName,

      secret: {
        name: this.name,
        url: 'PROM_URL',
        path: 'PROM_PATH',
        username: 'LOKI_USERNAME',
        password: 'LOKI_PASSWORD',
        instance:
          baseSecret
          + secret.metadata.withName(this.secret.name)
          + secret.metadata.withLabelsMixin({ 'app.kubernetes.io/name': this.secret.name })
          + secret.withData(
            {
              [this.secret.url]: std.base64(std.toString(secretData.url)),
              [this.secret.path]: std.base64(std.toString(secretData.path)),
              [this.secret.username]: std.base64(std.toString(secretData.username)),
              [this.secret.password]: std.base64(std.toString(secretData.password)),
            }
          ),
      },

      // redefines k8s-clu-mon's 'destination_logs.json' vector config file
      configs: {
        'destination_logs.json': {
          sinks: {
            [this.name]: {
              type: 'loki',
              local urlSplited = std.splitLimit(secretData.url, '//', 1),
              endpoint:
                // uses container environment variables taken from the secret
                urlSplited[0] + '//' + '${' + this.secret.username + '}' + ':'
                + '${' + this.secret.password + '}' + '@' + urlSplited[1]
              ,
              path: secretData.path,
              out_of_order_action: 'accept',
              buffer: {
                type: 'disk',
                max_size: 536870912,  // 512 megabytes
              },
              inputs: ['k8s-clu-mon_logs'],  // output from k8s-clu-mon - default name of the component for all k8s-clu-mon logs
              labels: {
                '*': '{{%"k8s-clu-mon".labels}}',  // all k8s-clu-mon labels
              }
              ,
              encoding: {
                codec: 'json',
              },
            },
          },
        },
      },

    },

  },

};


function(monitoredNamespaces=[], configsMixin={}, destination='prod')

  (
    kcm.new(config.namespace, config.cluster, config.platform)
    + kcm.withMonitoredNamespacesMixin(monitoredNamespaces)
    + kcm.withPrometheusRemoteWriteMixin([dests[destination].prometheus.remoteWrite])
    + kcm.withVectorConfigsMixin(dests[destination].loki.configs + configsMixin)
    + kcm.withVectorEnvFromSecretRefMixin([dests[destination].loki.secret.name])
  ).monitoring
  {
    'kube-prometheus'+: (import 'kp-metrics-tuned.libsonnet'),  // kube-prometheus metrics tuned

    secrets: [
      dests[destination].prometheus.secret.instance,
      dests[destination].loki.secret.instance,
    ],
  }
  + debug.new('##0', config)
  + debug.new('##1', dests)
