/*
Missing services in kind.
Required by ServiceMonitor created by kube-prometheus.
*/

local k = import 'k.libsonnet';

k.core.v1.list.new([

  //serviceKubeControllerManager:
  local svcName = 'kube-controller-manager';
  k.core.v1.service.new(
    svcName,
    { component: svcName },
    k.core.v1.servicePort.newNamed(name='https-metrics', port=10257, targetPort=10257)
  )
  + k.core.v1.service.metadata.withNamespace('kube-system')
  + k.core.v1.service.metadata.withLabels({ 'app.kubernetes.io/name': svcName })
  + k.core.v1.service.spec.withClusterIP('None')
  + k.core.v1.service.spec.withType('ClusterIP')
  ,

  //serviceKubeScheduler:
  local svcName = 'kube-scheduler';
  k.core.v1.service.new(
    svcName,
    { component: svcName },
    k.core.v1.servicePort.newNamed(name='https-metrics', port=10259, targetPort=10259)
  )
  + k.core.v1.service.metadata.withNamespace('kube-system')
  + k.core.v1.service.metadata.withLabels({ 'app.kubernetes.io/name': svcName })
  + k.core.v1.service.spec.withClusterIP('None')
  + k.core.v1.service.spec.withType('ClusterIP'),

])
