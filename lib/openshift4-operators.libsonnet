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

/**
 * \brief Validate instance
 *
 * This function takes an instance name and validates it against the supported
 * instance names and optionally against the instances present in the cluster
 * catalog.
 *
 * \arg instance The instance to validate
 * \arg checkTargets Whether to validate the instance against configured
 * component instances
 * \arg checkSource Free-form string included in the error output when
 * checking against configured component instances. This is included in the
 * error as "Unknown instance '<instance>' for <checkSource>".
 *
 * \returns `instance` if it validates. Throws an assertion error otherwise.
 */
local validateInstance(instance, checkTargets=false, checkSource='') =
  local supported_instances = std.set([
    'openshift-operators',
    'openshift-operators-redhat',
  ]);

  local use_custom_namespace = instanceParams(instance).useCustomNamespace;

  assert
    use_custom_namespace || std.setMember(instance, supported_instances) :
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


local subscription(name) =
  kube._Object(apigroup + '/v1alpha1', 'Subscription', name) {
    spec: {
      name: name,
      config: {
        affinity: {
          nodeAffinity: {
            requiredDuringSchedulingIgnoredDuringExecution: {
              nodeSelectorTerms: [ {
                matchExpressions: [ {
                  key: 'node-role.kubernetes.io/infra',
                  operator: 'Exists',
                } ],
              } ],
            },
          },
        },
      },
    },
  };

/**
 * \brief Wrapper to create `OperatorGroup` resources
 *
 * The result of this function can be used in the same way as resources
 * created by `kube.libjsonnet`.
 *
 * \arg name Value for `.metadata.name` of the resource
 *
 * \returns an `OperatorGroup` resource
 */
local OperatorGroup(name) =
  kube._Object(apigroup + '/v1', 'OperatorGroup', name);

/**
 * \brief Create a subscription object in an arbitrary namespace
 *
 * The result of this function can be used in the same way as resources
 * created by `kube.libjsonnet`.
 *
 * \arg namespace The namespace in which to create the resource
 * \arg name Name of the operator to install. Used as `.metadata.name` and
 * `.spec.name` of the resulting `Subscription` object.
 * \arg channel The channel for the subscription.
 * \arg source The source (`CatalogSource`) for the operator. Defaults to
 * `parameters.<instance>.defaultSource`.
 * \arg sourceNamespace The namespace holding the `CatalogSource`. Defaults to
 * `parameters.<instance>.defaultSourceNamespace`.
 * \arg installPlanApproval How to manage subscription updates. Valid options
 * are `Automatic` and `Manual`. Defaults to
 * `parameters.<instance>.defaultInstallPlanApproval`.
 *
 * \returns a preconfigured `Subscription` resource
 */
local namespacedSubscription =
  function(
    namespace,
    name,
    channel,
    source,
    sourceNamespace=params.defaultSourceNamespace,
    installPlanApproval=params.defaultInstallPlanApproval
  )
    subscription(name) {
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

/**
 * \brief Create a cluster-scoped subscription object in a namespace managed
 * by this component
 *
 * The result of this function can be used in the same way as resources
 * created by `kube.libjsonnet`.
 *
 * \arg instance Name of the component instance in which to create the
 * subscription
 * \arg name Name of the operator to install. Used as `.metadata.name` and
 * `.spec.name` of the resulting `Subscription` object.
 * \arg channel The channel for the subscription.
 * \arg source The source (`CatalogSource`) for the operator. Defaults to
 * `parameters.<instance>.defaultSource`.
 * \arg sourceNamespace The namespace holding the `CatalogSource`. Defaults to
 * `parameters.<instance>.defaultSourceNamespace`.
 * \arg installPlanApproval How to manage subscription updates. Valid options
 * are `Automatic` and `Manual`. Defaults to
 * `parameters.<instance>.defaultInstallPlanApproval`.
 *
 * \returns a preconfigured `Subscription` resource
 */
local managedSubscription =
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
    namespacedSubscription(
      _instance,
      name,
      channel,
      source,
      sourceNamespace,
      installPlanApproval
    );

{
  managedSubscription: managedSubscription,
  namespacedSubscription: namespacedSubscription,
  OperatorGroup: OperatorGroup,
  validateInstance: validateInstance,
}
