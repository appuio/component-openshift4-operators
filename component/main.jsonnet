// main template for openshift4-operators
local com = import 'lib/commodore.libjsonnet';
local espejote = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local operatorlib = import 'lib/openshift4-operators.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.openshift4_operators;


local namespace = operatorlib.validateInstance(params.namespace);

local nsmeta = {
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
};
local ns = kube.Namespace(namespace) + nsmeta;

local og = params.operator_group;
local operatorgroup =
  // Create cluster-scoped OperatorGroup
  operatorlib.OperatorGroup(namespace) {
    metadata+: {
      namespace: namespace,
    },
  } + {
    spec+: og.spec,
  };

local _patchNamespaceMeta = 'patch-namespace-meta';
local patchNamespaceMeta = [
  espejote.managedResource(_patchNamespaceMeta, params.namespace) {
    metadata+: {
      annotations+: {
        'syn.tools/description': |||
          Patches the operator namespace to add the cluster-monitoring label.
        |||,
      },
    },
    spec: {
      triggers: [
        {
          name: 'namespace',
          watchResource: {
            apiVersion: 'v1',
            kind: 'Namespace',
            name: params.namespace,
          },
        },
      ],
      serviceAccountRef: {
        name: _patchNamespaceMeta,
      },
      template: std.manifestJson({
        apiVersion: 'v1',
        kind: 'Namespace',
        metadata: {
          name: params.namespace,
        },
      } + nsmeta),
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      labels: {
        'app.kubernetes.io/name': _patchNamespaceMeta,
        'managedresource.espejote.io/name': _patchNamespaceMeta,
      },
      name: _patchNamespaceMeta,
      namespace: params.namespace,
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      labels: {
        'app.kubernetes.io/name': _patchNamespaceMeta,
        'managedresource.espejote.io/name': _patchNamespaceMeta,
      },
      name: 'operator:%s:%s' % [ _patchNamespaceMeta, params.namespace ],
    },
    rules: [
      {
        apiGroups: [ '' ],
        resources: [ 'namespaces' ],
        resourceNames: [ params.namespace ],
        verbs: [ '*' ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      labels: {
        'app.kubernetes.io/name': _patchNamespaceMeta,
        'managedresource.espejote.io/name': _patchNamespaceMeta,
      },
      name: 'operator:%s:%s' % [ _patchNamespaceMeta, params.namespace ],
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'operator:%s:%s' % [ _patchNamespaceMeta, params.namespace ],
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: _patchNamespaceMeta,
        namespace: params.namespace,
      },
    ],
  },
];

local subscription = params.subscription;
local sub =
  // Create subscription, if name is given
  if subscription.name != null then
    operatorlib.managedSubscription(
      params.namespace,
      subscription.name,
      subscription.channel
    ) + {
      spec+: subscription.spec,
    }
  else null;

{
  [namespace]: std.filter(
    function(it) it != null,
    (
      if namespace != 'openshift-operators' then [
        ns,
        operatorgroup,
      ]
      else patchNamespaceMeta
    ) + [ sub ]
  ),
}
