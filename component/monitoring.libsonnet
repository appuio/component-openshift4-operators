/*
This file adds ServiceMonitors in combination with the Prometheus component.

Warning: The operators monitored are instance independent,
         everything in this file must be instance independent.
*/

local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_operators;

local nsName = 'syn-monitoring-openshift4-operators';

local promInstance =
  if params.monitoring.instance != null then
    params.monitoring.instance
  else
    inv.parameters.prometheus.defaultInstance;

local endpoint = function(serverName)
  prom.ServiceMonitorHttpsEndpoint(serverName) {
    port: 'https-metrics',
    metricRelabelings: [
      {
        action: 'drop',
        regex: 'etcd_(debugging|disk|request|server).*',
        sourceLabels: [
          '__name__',
        ],
      },
      prom.DropRuntimeMetrics,
    ],
  };

local marketplaceOperatorMonitor = prom.ServiceMonitor('openshift-marketplace-operator') {
  metadata+: {
    namespace: nsName,
  },
  spec+: {
    endpoints: [
      endpoint('marketplace-operator-metrics.openshift-marketplace.svc'),
    ],
    namespaceSelector: {
      matchNames: [
        'openshift-marketplace',
      ],
    },
    selector: {
      matchLabels: {
        name: 'marketplace-operator',
      },
    },
  },
};

local olmOperatorMonitor = prom.ServiceMonitor('openshift-olm-operator') {
  metadata+: {
    namespace: nsName,
  },
  spec+: {
    endpoints: [
      endpoint('olm-operator-metrics.openshift-operator-lifecycle-manager.svc'),
    ],
    namespaceSelector: {
      matchNames: [
        'openshift-operator-lifecycle-manager',
      ],
    },
    selector: {
      matchLabels: {
        app: 'olm-operator',
      },
    },
  },
};

local catalogOperatorMonitor = prom.ServiceMonitor('openshift-catalog-operator') {
  metadata+: {
    namespace: nsName,
  },
  spec+: {
    endpoints: [
      endpoint('catalog-operator-metrics.openshift-operator-lifecycle-manager.svc'),
    ],
    namespaceSelector: {
      matchNames: [
        'openshift-operator-lifecycle-manager',
      ],
    },
    selector: {
      matchLabels: {
        app: 'catalog-operator',
      },
    },
  },
};

if params.monitoring.enabled && std.member(inv.applications, 'prometheus') then
  {
    monitoring: [
      prom.RegisterNamespace(
        kube.Namespace(nsName),
        instance=promInstance
      ),
      marketplaceOperatorMonitor,
      catalogOperatorMonitor,
      olmOperatorMonitor,
    ],
  }
else
  std.trace(
    'Monitoring disabled or component `prometheus` not present, '
    + 'not deploying ServiceMonitors',
    {}
  )
