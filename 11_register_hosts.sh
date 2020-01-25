#!/usr/bin/bash

set -ex

source common.sh
source ocp_install_env.sh
source logging.sh

eval "$(go env)"

function list_workers() {
    # Includes -machine and -machine-namespace
    cat $NODES_FILE | \
        jq '.nodes[] | select(.name | contains("worker")) | {
           name,
           driver,
           address:.driver_info.address,
           port:.driver_info.port,
           user:.driver_info.username,
           password:.driver_info.password,
           mac: .ports[0].address
           } |
           .name + " " +
           .address + " " +
           .user + " " + .password + " " + .mac' \
       | sed 's/"//g'
}

# Register the workers without a consumer reference so they are
# available for provisioning.
function make_bm_workers() {
    # Does not include -machine or -machine-namespace
    while read name address user password mac; do
        go run $SCRIPTDIR/make-bm-worker/main.go \
           -address "$address" \
           -password "$password" \
           -user "$user" \
           -boot-mac "$mac" \
           "$name"
    done
}

if [ "$TEST_CUSTOM_MAO" = true ]; then
  # Now that the deployment is up, replace the machine-api-operator image with
  # one that needs to be tested before we bring up the workers.
  $SCRIPTDIR/run-custom-mao.sh
fi

list_workers | make_bm_workers | tee $SCRIPTDIR/ocp/worker_crs.yaml
if test ${NUM_WORKERS} -gt 0 ; then
    # TODO - remove this once we set worker replicas to ${NUM_WORKERS} in
    # install-config, which will be after the machine-api-operator can deploy the
    # baremetal-operator
    oc scale machineset -n openshift-machine-api ${CLUSTER_NAME}-worker-0 --replicas=${NUM_WORKERS}

    # Run the fix_certs.sh script periodically as a workaround for
    # https://github.com/openshift-metalkube/dev-scripts/issues/260
    sudo systemd-run --on-active=30s --on-unit-active=1m --unit=fix_certs.service $(dirname $0)/fix_certs.sh
fi

# Check if file exists
[ -s "$SCRIPTDIR/ocp/worker_crs.yaml" ] || exit 0

oc --config ocp/auth/kubeconfig apply -f $SCRIPTDIR/ocp/worker_crs.yaml --namespace=openshift-machine-api
