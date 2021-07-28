/**
 * \file Library with public methods provided by component openshift4-operators.
 */

local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();

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


local registerSubscription =
  function(
    instance,
    name,
    channel,
    source='redhat-operators',
    sourceNamespace='openshift-marketplace',
    installPlanApproval='Automatic'
  )
    local _instance = validateInstance(
      instance,
      checkTargets=true,
      checkSource='subscription %s' % [ name ]
    );
    kube._Object('operators.coreos.com/v1alpha1', 'Subscription', name) {
      metadata+: {
        namespace: _instance,
      },
      spec: {
        channel: channel,
        installPlanApproval: installPlanApproval,
        source: source,
        sourceNamespace: sourceNamespace,
        name: name,
      },
    };

{
  registerSubscription: registerSubscription,
  validateInstance: validateInstance,
}
