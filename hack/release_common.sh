#!/usr/bin/env bash
set -euo pipefail

CURRENT_MAJOR_VERSION="0"
HELM_CHART_VERSION="v${CURRENT_MAJOR_VERSION}-${SNAPSHOT_TAG}"
RELEASE_VERSION=${RELEASE_VERSION:-"${SNAPSHOT_TAG}"}
RELEASE_PLATFORM="--platform=linux/amd64"

requireCloudProvider(){
  if [ -z "$CLOUD_PROVIDER" ]; then
      echo "CLOUD_PROVIDER environment variable is not set: 'export CLOUD_PROVIDER=aws'"
      exit 1
  fi
}

authenticate() {
  aws ecr get-login-password | docker login --username AWS --password-stdin ${RELEASE_REPO}
}


buildImages() {
    HELM_CHART_VERSION=$1
    CONTROLLER_DIGEST=$(GOFLAGS=${GOFLAGS} KO_DOCKER_REPO=${RELEASE_REPO} ko publish -B -t ${RELEASE_VERSION} ${RELEASE_PLATFORM} ./cmd/controller)
    WEBHOOK_DIGEST=$(GOFLAGS=${GOFLAGS} KO_DOCKER_REPO=${RELEASE_REPO} ko publish -B -t ${RELEASE_VERSION} ${RELEASE_PLATFORM} ./cmd/webhook)
    yq -y -i --arg digest ${CONTROLLER_DIGEST} '.controller.image=$digest' charts/karpenter/values.yaml
    yq -y -i --arg digest ${WEBHOOK_DIGEST} '.webhook.image=$digest' charts/karpenter/values.yaml
    yq -y -i --arg version ${RELEASE_VERSION} '.appVersion=$version' charts/karpenter/Chart.yaml
    yq -y -i --arg version ${HELM_CHART_VERSION} '.version=$version' charts/karpenter/Chart.yaml
}
