#!/usr/bin/env bash

# We need these lines because ansible group was called pulp and now we are calling it repo-manager
grep repo-manager * -rl | xargs sed -i 's/repo-manager/pulp/g'
mv config/samples/{repo-manager,pulp}.pulpproject.org_v1beta1_pulp.yaml
mv config/samples/{repo-manager,pulp}.pulpproject.org_v1beta2_pulp.yaml
mv config/samples/{repo-manager,pulp}_v1alpha1_pulpbackup.yaml
mv config/samples/{repo-manager,pulp}_v1alpha1_pulprestore.yaml
mv config/samples/{repo-manager,pulp}_v1alpha1_pulp.yaml
mv apis/{repo-manager,pulp}.pulpproject.org
rm bundle/manifests/repo-manager.pulpproject.org*

set -xue

export USERNAME=rhn_support_hyagi
export VERSION=0.0.2
export OLD_VERSION=0.0.1
export IMG=quay.io/$USERNAME/golang-pulp-operator:v$VERSION
export BUNDLE_IMG=quay.io/$USERNAME/golang-pulp-operator-bundle:v$VERSION
export CATALOG_IMG=quay.io/$USERNAME/ansible-pulp-operator-index:v$VERSION

sed  -r -i "s/^BUNDLE_IMGS \?= .*$/BUNDLE_IMGS ?= \$(BUNDLE_IMG),quay.io\/rhn_support_hyagi\/ansible-pulp-operator-bundle:v${OLD_VERSION}/g" Makefile
make bundle CHANNELS="alpha,beta" DEFAULT_CHANNEL=alpha
make bundle-build bundle-push
make docker-build docker-push
make catalog-build catalog-push
oc -nopenshift-marketplace patch catalogsource pulp-operator-cs --type=merge -p '{"spec": {"image": "'$CATALOG_IMG'"}}'


# update crd
oc -npulp get pulps.pulp.pulpproject.org

# patch the nodeport from string to int
oc -npulp patch pulps example-pulp --type=merge -p '{"spec": {"nodeport_port": 31234 }}'