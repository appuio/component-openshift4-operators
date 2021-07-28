/**
 * \file Library with public methods provided by component openshift4-operators.
 */

local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();

local params = inv.parameters.openshift4_operators;
local instanceParams(instance) =
  local ikey = std.strReplace(instance, '-', '_');
  params + com.getValueOrDefault(inv.parameters, ikey, {});

local apigroup = 'operators.coreos.com';

local validateInstance(instance, checkTargets=false, checkSource='') =
  local supported_instances = std.set([
    'openshift-operators',
    'openshift-operators-redhat',
  ]);

  assert
    std.setMember(instance, supported_instances) :
    "\n  Invalid instance '%s' for component openshift4-operators." % [
      instance,
    ] +
    '\n  Supported instances are %s' % [
      supported_instances,
    ];

  local appentry = 'openshift4-operators as %s' % [ instance ];
  assert
    !checkTargets || std.member(inv.applications, appentry) :
    "\n  Unknown openshift4-operators instance '%s' for %s." % [
      instance,
      checkSource,
    ] +
    "\n  Did you forget to configure application '%s'?" % [
      appentry,
    ];

  instance;


local Subscription(name) =
  kube._Object(apigroup + '/v1alpha1', 'Subscription', name) {
    spec: {
      name: name,
    },
  };

local OperatorGroup(name) =
  kube._Object(apigroup + '/v1', 'OperatorGroup', name);

local globalSubscription =
  function(
    instance,
    name,
    channel,
    source=instanceParams(instance).defaultSource,
    sourceNamespace=instanceParams(instance).defaultSourceNamespace,
    installPlanApproval=instanceParams(instance).defaultInstallPlanApproval
  )
    local _instance = validateInstance(
      instance,
      checkTargets=true,
      checkSource='subscription %s' % [ name ]
    );
    Subscription(name) {
      metadata+: {
        namespace: _instance,
      },
      spec+: {
        channel: channel,
        installPlanApproval: installPlanApproval,
        source: source,
        sourceNamespace: sourceNamespace,
      },
    };

local namespacedSubscription =
  function(
    namespace,
    name,
    channel,
    source,
    sourceNamespace=params.defaultSourceNamespace,
    installPlanApproval=params.defaultInstallPlanApproval
  )
    Subscription(name) {
      metadata+: {
        namespace: namespace,
      },
      spec+: {
        channel: channel,
        installPlanApproval: installPlanApproval,
        source: source,
        sourceNamespace: sourceNamespace,
      },
    };

{
  globalSubscription: globalSubscription,
  namespacedSubscription: namespacedSubscription,
  OperatorGroup: OperatorGroup,
  validateInstance: validateInstance,
}
