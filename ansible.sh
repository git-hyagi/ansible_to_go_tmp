#!/usr/bin/env bash


# You can remove theses lines
# I use them to reinstall from scratch
oc delete project pulp
oc get crd -oname |awk '/pulp/{print $1}'|xargs oc delete
oc -n openshift-marketplace delete catalogsource pulp-operator-cs


# Installation starts here
set -xeu

export USERNAME=rhn_support_hyagi
export VERSION=0.0.1
export IMG=quay.io/$USERNAME/ansible-pulp-operator:v$VERSION
export BUNDLE_IMG=quay.io/$USERNAME/ansible-pulp-operator-bundle:v$VERSION
export CATALOG_IMG=quay.io/$USERNAME/ansible-pulp-operator-index:v$VERSION
make bundle bundle-build bundle-push
make docker-build docker-push
make catalog-build catalog-push

# create a secret (in this case from podman auth.json) if quay repo is private
oc -nopenshift-marketplace get secret quay-io || oc -nopenshift-marketplace create secret docker-registry quay-io --from-file=.dockerconfigjson=${XDG_RUNTIME_DIR}/containers/auth.json

oc get project pulp || oc new-project pulp

oc apply -f- <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: pulp-operator-cs
  namespace: openshift-marketplace
spec:
  displayName: pulp-operator
  publisher: Pulp Community
  sourceType: grpc
  image: $CATALOG_IMG
  updateStrategy:
    registryPoll:
      interval: 1m
EOF

sleep 1
oc -nopenshift-marketplace secret link pulp-operator-cs quay-io --for=pull
oc -nopenshift-marketplace secret link default quay-io --for=pull
oc -nopenshift-marketplace delete pods -l olm.catalogSource=pulp-operator-cs

oc apply -f- <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: pulp-operator-group
  namespace: pulp
spec:
  targetNamespaces:
  - pulp
EOF

oc apply -f-<<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/pulp-operator.pulp: ""
  name: pulp-operator
  namespace: pulp
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: pulp-operator
  source: pulp-operator-cs
  sourceNamespace: openshift-marketplace
  startingCSV: pulp-operator.v$VERSION
EOF

oc -npulp get secret redhat-operators-pull-secret || oc -npulp create secret docker-registry redhat-operators-pull-secret --from-file=.dockerconfigjson=${XDG_RUNTIME_DIR}/containers/auth.json
oc -npulp get sa pulp-operator-sa && oc -npulp secret link pulp-operator-sa redhat-operators-pull-secret --for=pull
oc -npulp wait --for=condition=CatalogSourcesUnhealthy=False subscription/pulp-operator
sleep 35
oc -npulp apply -f /tmp/simple.yaml

