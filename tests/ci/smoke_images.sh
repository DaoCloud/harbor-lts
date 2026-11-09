#!/bin/bash
# Fail if any built binary cannot start on its image, for example because it was
# linked against a newer glibc or built for another architecture. usage: smoke_images.sh <tag>
TAG=$1
rc=0
check() {
    out=$(docker run --rm --entrypoint "$2" goharbor/$1:$TAG ${3:---help} 2>&1 | head -5)
    if echo "$out" | grep -qE 'GLIBC_|exec format error|not found|cannot execute|no such file'; then
        echo "FAIL $1 $2: $out"; rc=1
    else
        echo "ok   $1 $2"
    fi
}
check harbor-core /harbor/harbor_core
check harbor-jobservice /harbor/harbor_jobservice
check harbor-registryctl /home/harbor/harbor_registryctl
check registry-photon /usr/bin/registry_DO_NOT_USE_GC --version
check chartmuseum-photon /home/chart/chartm --version
check trivy-adapter-photon /home/scanner/bin/scanner-trivy --version
check trivy-adapter-photon /usr/local/bin/trivy --version
check harbor-exporter /harbor/harbor_exporter
check nginx-photon nginx -v
check harbor-portal nginx -v
exit $rc
