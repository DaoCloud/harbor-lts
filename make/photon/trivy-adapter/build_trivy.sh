#!/bin/bash
# Build the Trivy CLI from source with the given Go image. usage: build_trivy.sh <version> <golang image>
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "usage: build_trivy.sh <version> <golang image>"
  exit 1
fi

VERSION="$1"
GOLANG_IMAGE="$2"

cd $(dirname $0)
mkdir -p binary

docker run --rm -v $PWD/binary:/out -e CGO_ENABLED=0 -e GOBIN=/out $GOLANG_IMAGE \
  go install -trimpath -ldflags "-s -w -X github.com/aquasecurity/trivy/pkg/version/app.ver=${VERSION#v}" \
  github.com/aquasecurity/trivy/cmd/trivy@$VERSION
