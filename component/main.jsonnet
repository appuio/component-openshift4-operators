// main template for openshift4-operators
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local operatorlib = import 'lib/openshift4-operators.libsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_operators;


local namespace = operatorlib.validateInstance(params.namespace);

{
  [namespace]: [
    kube.Namespace(namespace) {
      metadata+: {
        annotations+: std.prune(params.namespaceAnnotations),
        labels+: {
          // enable cluster monitoring when instantiating to manage
          // namespace openshift-operators-redhat
          'openshift.io/cluster-monitoring':
            '%s' % [ namespace == 'openshift-operators-redhat' ],
          // ignore namespace by user-workload monitoring
          'openshift.io/user-monitoring': 'false',
        },
      },
    },
    // Create cluster-scoped OperatorGroup
    operatorlib.OperatorGroup(namespace) {
      metadata+: {
        namespace: namespace,
      },
    },
  ],
}
