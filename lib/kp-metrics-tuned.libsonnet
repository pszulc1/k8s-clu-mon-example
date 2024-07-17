/*
k8s-clu-mon kube-prometheus metrics tuned at a source to reduce expensive or not useful one.
Redefinition should be made by hand for each ServiceMonitor and PodMonitor :(

To get all ServiceMonitors names:
    tk eval <path-to-environment) | jq '..|select(.kind=="ServiceMonitor")?|.metadata.name'

To get path and some details, including current definition:
    tk eval <path-to-environment) \
    | jq '{index:0, path:path(.. | select(.kind=="ServiceMonitor")? ), object:.}' \
    | jq 'until(.index==(.path|length); {index:(.index+1), path: .path, object: .object[.path[.index]]})' \
    | jq '{path:.path, "smon": {metadata_name: .object.metadata.name, spec_endpoints:.object.spec.endpoints, spec_jobLabel: .object.spec.jobLabel}}'

Example selection (patch) below.
All redefinitions are added to existing one at the end of metricRelabelings.

Another way of selecting metrics is a use of remoteWrite.[].writeRelabelConfigs  (see example in main.jsonnet).
*/

{

  kubeStateMetrics+: {
    serviceMonitor+: {
      spec+: {
        endpoints: [
          super.endpoints[0]
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex: 'kube_(.+)_created|kube_(.+)_info|kube_endpoint_ports',
                action: 'keep',
              },
            ],
          }
          ,
          super.endpoints[1],  // kube-state-metrics self metrics whithout modifications
        ],
      },
    },
  },

  kubernetesControlPlane+: {

    podMonitorKubeProxy+: {
      spec+: {
        podMetricsEndpoints: [
          super.podMetricsEndpoints[0]
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex: 'kubeproxy_(.+)',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },

    serviceMonitorApiserver+: {
      spec+: {
        endpoints: [
          super.endpoints[0]
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex: 'apiserver_request_total',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },

    serviceMonitorCoreDNS+: {
      // not available at GKE
      spec+: {
        endpoints: [
          super.endpoints[0]
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex:
                  'coredns_build_info|coredns_dns_responses_total|coredns_dns_request_duration_seconds_bucket|coredns_dns_requests_total',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },

    serviceMonitorKubeControllerManager+: {
      // not available at GKE
      spec+: {
        endpoints: [
          super.endpoints[0]
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex:
                  'workqueue_queue_duration_seconds_bucket|workqueue_adds_total|workqueue_depth|rest_client_request_duration_seconds_bucket'
                  + '|' +
                  'rest_client_requests_total|process_cpu_seconds_total|process_resident_memory_bytes',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },

    serviceMonitorKubeScheduler+: {
      // not available at GKE
      // whithout modifications
    },

    serviceMonitorKubelet+: {
      spec+: {
        endpoints: [
          super.endpoints[0]  // kubelet itself
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex:
                  'process_(.+)|kubelet_started_(.+)',
                action: 'keep',
              },
            ],
          },
          super.endpoints[1]  // cAdvisor
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex: 'container_cpu_usage_seconds_total|container_memory_working_set_bytes',
                action: 'keep',
              },
            ],
          },
          super.endpoints[2],  // metrics/probes whithout modifications
        ],
      },
    },
  },


  nodeExporter+: {
    serviceMonitor+: {
      spec+: {
        endpoints: [
          super.endpoints[0]
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex: 'node_exporter_build_info|node_memory_Mem(.+)|node_cpu_seconds_total',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },
  },

  prometheus+: {
    serviceMonitor+: {
      spec+: {
        endpoints: [
          super.endpoints[0]  // prometheus itself
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex:
                  'prometheus_(build_info|ready)|prometheus_target_scrape_pools_(.+)'
                  + '|' +
                  'prometheus_agent_active_series|prometheus_remote_storage_bytes_total|prometheus_sd_discovered_targets',
                action: 'keep',
              },
            ],
          },
          super.endpoints[1]  // reloader
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex: 'reloader_(.+)|',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },
  },

  prometheusOperator+: {
    serviceMonitor+: {
      spec+: {
        endpoints: [
          super.endpoints[0]
          {
            metricRelabelings+: [
              {
                sourceLabels: ['__name__'],
                regex: 'prometheus_operator_(build_info|ready)|prometheus_operator_list_operations_failed_total|prometheus_operator_managed_resources',
                action: 'keep',
              },
            ],
          },
        ],
      },
    },
  },

}
