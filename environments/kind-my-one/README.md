# kind-my-one

`my-kind-example-config.yaml` contains the definition of the `kind` cluster.  
This is a modified example of the configuration indicated in [kind->Quick Start->Advanced](https://kind.sigs.k8s.io/docs/user/quick-start/#advanced).  
The modifications concern `kube-scheduler`, `kube-controller-manager` and `kube-proxy`.  
Monitoring `etcd` is not configured.  

`servicesControlPlane.jsonnet` contains lacking service definitions.  
