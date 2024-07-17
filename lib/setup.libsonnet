/*
Setup to be deployed first.
*/

local kcm = import 'k8s-clu-mon/main.libsonnet';
local debug = (import 'k8s-clu-mon/debug.libsonnet')(std.thisFile, (import 'global.json').debug);

local config = import 'config.libsonnet';


(kcm.new(config.namespace, config.cluster, config.platform)).setup
+ debug.new('##0', config)
