/*
Common config utilizing current tanka environment definition and environment's global variables.
*/

{
  local tkenv = (import 'tk').env,
  local base = self,

  name: 'monitoring',  // complete solution's default name

  namespace: tkenv.spec.namespace,
  cluster: importstr '../cluster-name.txt',

  platform: (function(x) if std.isEmpty(x) then null else x)(importstr '../platform.txt'),

  labels: {
    'app.kubernetes.io/part-of': base.name,
    'app.kubernetes.io/version': (import 'global.json').version,
    tkenv:
      (
        function(str)
          local sufix = std.splitLimitR(str, '/', 1);
          if std.length(sufix) != 2 then str else sufix[1]
      )
      (tkenv.metadata.name),  // truncated as the full path may be too long for the label value
  },
}
