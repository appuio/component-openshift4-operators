local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_operators;
local argocd = import 'lib/argocd.libjsonnet';

// Use `openshift-operators` as fallback namespace
// By using a static value here, we don't get unexpected changes when users
// create new instances of this component.
local app = argocd.App('openshift4-operators', 'openshift-operators');

local appPath =
  local project = std.get(app, 'spec', { project: 'syn' }).project;
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/openshift4-operators' % appPath]: app,
}
