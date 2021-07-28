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

  instance;

{
  validateInstance: validateInstance,
}
