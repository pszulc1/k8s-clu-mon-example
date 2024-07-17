/*
Utilities.
*/

(import 'k8s-clu-mon/utils.libsonnet')
+ {
  prefixedName(prefix,name):: prefix + '--' + name,
}
