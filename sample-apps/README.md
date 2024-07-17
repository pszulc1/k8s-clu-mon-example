# sample-apps

A few fake applications for test purposes.  
Each subdirectory stands for a different application, which may consist of several components.  

The `*-exposed.yaml` services use `metrics_exposed: "true"` matchLabels.  

## opalcbox

In a way modelled on the actual components of `opalcbox.pl` application.  

```sh
kubectl create namespace prod-opalcbox

kubectl apply -f opalcbox/opalcbox-pl -n prod-opalcbox
kubectl apply -f opalcbox/uke-ftps -n prod-opalcbox

# see http://localhost:7777/metrics to check the available metrics of a component 
kubectl port-forward service/opalcbox-pl-exposed 7777:metrics -n prod-opalcbox
```

## services

```sh
kubectl create namespace prod-services

kubectl apply -f services/redirect -n prod-services
```

## otherapp

```sh
kubectl create namespace prod-otherapp

kubectl apply -f otherapp/awesome1 -n prod-otherapp
```
