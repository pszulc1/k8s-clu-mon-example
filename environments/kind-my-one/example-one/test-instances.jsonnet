/*
Local instances for test purposes.
*/

{
  local config = import 'config.libsonnet',

  prometheus: (import 'k8s-clu-mon/test-instances/prometheus.libsonnet')(config.namespace, config.labels),

  /*
  To get final loki configuration:

    tk eval environments/kind-my-one/example-one/test-instances.jsonnet \
    | jq '.["loki"].config_file.data["config.yaml"]' \
    | yq -P | yq -o json | jq

  */
  loki: (import 'k8s-clu-mon/test-instances/loki.libsonnet')(config.namespace, config.labels),

  grafana: (import 'k8s-clu-mon/test-instances/grafana.libsonnet')(config.namespace, config.labels),
}
