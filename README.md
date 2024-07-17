# k8s-clu-mon-example

Examples of the use of the jsonnet `k8s-clu-mon` library to monitor several clusters.  

A monitoring application will be deployed in each cluster.  
An extracted data will be send to central monitoring system which in this case is [Grafana Cloud](https://grafana.com/products/cloud/).  
Logs will be sent to [Loki](https://grafana.com/oss/loki/), while metrics to [prometheus](https://prometheus.io/) instance of Grafana Cloud.  
Some scraped metrics will be dropped to restrain a volume of data sent to Grafana Cloud.  

The example uses [Grafana Tanka](https://tanka.dev/) and some other additional tools eg. [jq](https://jqlang.github.io/jq/), [jb](https://github.com/jsonnet-bundler/jsonnet-bundler).  

## Quickstart

```sh
git clone git@github.com:pszulc1/k8s-clu-mon-example.git --branch v0.1.1
cd k8s-clu-mon-example/
jb install
```

Go to [Working deployment: `environments/kind-my-one/example-one`](#working-deployment-environmentskind-my-oneexample-one).  


## Initial project setup

```sh
# the k8s-libsonnet version should correspond to k8s server version
# and k8s-libsonnet version used in k8s-clu-mon package
tk init -f --k8s 1.28
tk env remove environments/default/ # unnecessary environment

echo 'vendor/' >> .gitignore

jb install github.com/pszulc1/k8s-clu-mon@v0.1.1
```

## Cluster-specific configuration of environments

```sh
# cluster name obtained from `kubectl config get-clusters`
CLUSTERNAME=gke_opalcbox_europe-west1-c_stdprod1
# server IP address for the cluster
SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$CLUSTERNAME\")].cluster.server}")

mkdir environments/$CLUSTERNAME
echo -n $CLUSTERNAME > environments/$CLUSTERNAME/cluster-name.txt
# in this case it is a GKE cluster
echo -n gke > environments/$CLUSTERNAME/platform.txt

# first environment, name must be a valid k8s label value
TKENV=environments/$CLUSTERNAME/example-one
tk env add $TKENV --namespace=monitoring
tk env set $TKENV --server=$SERVER
# server applyStrategy is needed to avoid `metadata.annotations: Too long:` error
# see: https://tanka.dev/server-side-apply
# alternatively you can (probably) use `tk apply --apply-strategy server` (haven't try)
cat $TKENV/spec.json | jq '.spec += {applyStrategy:"server"}' > $TKENV/spec.json

# next environment concerning the same cluster
TKENV=environments/$CLUSTERNAME/next-environment
# ...
```

Check `tk env list` to get all environments defined for the different clusters available in this repo.  
Check `ls -lp environments` to get all monitored clusters.  
`kind-my-one` is working example of kind cluster monitoring.  
`gke_opalcbox_europe-west1-c_stdprod1`, `other-cluster` and `yet-another-cluster` are not working examples.  

## Generic deployment schema

### `setup.jsonnet`: CRDs, namespace and Prometheus Operator

```sh
tk apply environments/gke_opalcbox_europe-west1-c_stdprod1/example-one/setup.jsonnet

# some checks
kubectl get all -n monitoring
kubectl get crd | grep monitoring.coreos.com
```

### `monitoring.jsonnet`: Monitoring components

Make sure that the monitored application namespaces enlisted in `monitoredNamespaces` parameter of `(import 'monitoring.libsonnet')()` in `<ENVIRONMENT>/monitoring.jsonnet` have been created in the cluster.  
Otherwise, errors will arise.

```sh
tk apply environments/gke_opalcbox_europe-west1-c_stdprod1/example-one/monitoring.jsonnet

# some checks
kubectl get all -n monitoring
kubectl get servicemonitors --all-namespaces
```

## Working deployment: `environments/kind-my-one/example-one`

Set up a [`kind`](https://kind.sigs.k8s.io/) cluster (see `environments/kind-my-one/README.md` for details):  

```sh
kind create cluster --name my-one --config environments/kind-my-one/my-kind-example-config.yaml
jsonnet -J lib -J vendor environments/kind-my-one/servicesControlPlane.jsonnet | kubectl apply -f -
```

Update Tanka apiServer:  

```sh
# cluster name from `kubectl config get-clusters`
CLUSTERNAME=kind-my-one
TKENV=environments/$CLUSTERNAME/example-one
# assuming the context name is the same as the cluster name
tk env set $TKENV --server-from-context $CLUSTERNAME
```

Create CRDs, namespace and Prometheus Operator (`setup.jsonnet`):  

```sh
tk apply environments/kind-my-one/example-one/setup.jsonnet
```

Launch sample monitored applications according to `sample-apps/README.md`.  

By default, the monitoring application runs in test mode in which the collected metrics and logs are sent to the local Prometheus and Loki instances respectively. These local instances help tune metrics and logs before sending them to a central monitoring system.  

In test mode local test instances must be started:

```sh
tk apply environments/kind-my-one/example-one/test-instances.jsonnet
```

In order to export to central monitoring system, the following modifications must be made:

- set `destination='prod'` in `(import 'monitoring.libsonnet')()` in `environments/kind-my-one/example-one/monitoring.jsonnet`
- define properly values in `lib/grafana-cloud-prom-secret.json` and `lib/grafana-cloud-loki-secret.json`

In both test and prod mode, finally run the monitoring components:  

```sh
tk apply environments/kind-my-one/example-one/monitoring.jsonnet

# some checks
kubectl get all -n monitoring
kubectl get servicemonitors --all-namespaces
kubectl get crd | grep monitoring.coreos.com
```

## Service

```sh
# prometheus operator log
PROM_OPERATOR=$(kubectl get pods -n monitoring --no-headers -o custom-columns=":metadata.name" | grep prometheus-operator-)
kubectl logs $PROM_OPERATOR -n monitoring

# prometheus agent log - does it do remote writes?
kubectl logs pod/prom-agent-k8s-0 -n monitoring

# prometheus agent analysis available at http://localhost:9097
# see Status -> Targets to get labels which were discovered
kubectl port-forward service/prometheus-k8s 9097:web -n monitoring

# for vector agent analysis (per pod) - the correct <vector-agent-pod-name> must be provided
kubectl port-forward pod/<vector-agent-pod-name> 9099:api -n monitoring
# for vector aggregator analysis
kubectl port-forward service/vector-aggregator 9099:api -n monitoring

# topology analysis (vector must be installed locally):
vector top --url http://localhost:9099/graphql
# metrics components observation
vector tap --url http://localhost:9099/graphql internal_metrics | jq
vector tap --url http://localhost:9099/graphql --inputs-of prom_exporter | jq
# logs component observation
vector tap --url http://localhost:9099/graphql k8s-clu-mon_logs | jq

# metrics are also available at http://localhost:9191/metrics
# for vector agent
kubectl port-forward pod/<vector-agent-pod-name> 9191:metrics -n monitoring
# for vector aggregator
kubectl port-forward service/vector-aggregator 9191:metrics -n monitoring
```

Test mode components:  

```sh
# prometheus test instance available at http://localhost:9090
# see Status -> TSDB Status to get Head Cardinality Stats
kubectl port-forward service/prometheus 9090:web -n monitoring

# loki test instance port forward for read and write
kubectl port-forward service/read 3100:80 -n monitoring
kubectl port-forward service/write 3200:80 -n monitoring
# feeding with fake logs
jsonnet --ext-str date=$(date +%s%N) fake-log-line.jsonnet | curl -v -H "Content-Type: application/json" http://localhost:3200/loki/api/v1/push -d @-
# some queries
curl --get -s http://localhost:3100/loki/api/v1/labels | jq
curl --get -s http://localhost:3100/loki/api/v1/series | jq
# LogQL
curl --get -s http://localhost:3100/loki/api/v1/query_range --data-urlencode 'query={agent="the-one", colour="blue"}' --data-urlencode 'start=1711372081000000000' | jq '.data.result'

# grafana test instance for convenient analysis
kubectl port-forward service/grafana 3000:3000 -n monitoring
# gui available at http://localhost:3000/
# use http://read as loki data source to get data from loki test instance
# use http://prometheus:9090 as prometheus data source to get data from prometheus test instance
```

## Monitoring

Use pods labels `app.kubernetes.io/*` promoted to metrics labels `app_kubernetes_io_*` to get metrics related to a specified pod.  
You can also use the `job` label, which is by default set as a value of `app.kubernetes.io/name` service label.  
If the label is not defined or its value is empty `job` will be defined as the name of the service monitored by Service Monitor.  
Use the `k8s_clu_mon_*` labels to filter the cluster from which the data is taken.  
See [k8s-clu-mon/docs/README.md](https://github.com/pszulc1/k8s-clu-mon/blob/main/docs/README.md) for more information.  

Use Prometheus Grafana Cloud or Grafana test instance (in test mode).  

Some example queries:  

```sh
# to analyze the total number of metrics scraped from a specific application using custom ServiceMonitors
sum(count by (__name__)({k8s_clu_mon_cluster="kind-my-one", namespace="prod-opalcbox", app="opalcbox"}))

# to get all jobs gathering metrics concerning specified namespace
count by (job)({k8s_clu_mon_cluster="kind-my-one", namespace="prod-opalcbox"})

# a specific metric from sample-apps/services/redirect, custom ServiceMonitor
nginx_http_requests_total{k8s_clu_mon_cluster="kind-my-one", namespace="prod-services", app_kubernetes_io_name="redirect", job="redirect"}
# a specific metric from sample-apps/opalcbox, custom ServiceMonitors
nginx_http_requests_total{k8s_clu_mon_cluster="kind-my-one", namespace="prod-opalcbox", app="opalcbox", component="uke-ftps"}

# a specific metric from sample-apps/services, defaultServiceMonitor
nginx_http_requests_total{k8s_clu_mon_cluster="kind-my-one", namespace="prod-otherapp", app_kubernetes_io_name="awesome1"}
# a specific metric from sample-apps/opalcbox, defaultServiceMonitor
nginx_http_requests_total{k8s_clu_mon_cluster="kind-my-one", namespace="prod-opalcbox", job="uke-ftps-12586-exposed"}

# example metric concerning parameters of particular container 
container_memory_working_set_bytes{k8s_clu_mon_cluster="kind-my-one", namespace="prod-opalcbox", container="ftps-server"}

# analysis of the individual components of the monitoring application
# metrics:
prometheus_remote_storage_bytes_total{k8s_clu_mon_cluster="kind-my-one", namespace="monitoring", app_kubernetes_io_name="prometheus-agent"}
container_memory_working_set_bytes{k8s_clu_mon_cluster="kind-my-one",container="vector",pod=~"vector-(.)*"}
# logs:
{k8s_clu_mon_cluster="kind-my-one",namespace="monitoring",app_kubernetes_io_name="prometheus-agent"} | json level="level" | level!="info"
{k8s_clu_mon_cluster="kind-my-one",namespace="monitoring",app_kubernetes_io_name="vector-aggregator"} | json level="level" | level!="INFO"
```

## Development

To check values generated by debug messages set `debug` to `true` in `./lib/global.json` and use (for example):

```sh
./d2j environments/kind-my-one/example-one/monitoring.jsonnet lib/monitoring.libsonnet 1 | jq '.prod.loki.configs'
./d2j environments/kind-my-one/example-one/monitoring.jsonnet environments/kind-my-one/example-one/monitoring.jsonnet 2 | jq 'keys'
./d2j environments/kind-my-one/example-one/monitoring.jsonnet environments/kind-my-one/example-one/opalcbox.jsonnet 3 | jq 'keys'
```

Search for `debug.new` in source files for other message ids.  

To close the new release set `(lib/global.json).version` consistently with the new release tag.  
