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
# NGINX2Root is fixed in nginx 1.30.7. Check the binary and the rpm database that scanners read,
# as scanners do not know about NGINX2Root yet. The images have no rpm command, so ask tdnf.
NGINX_MIN=1.30.7
check_nginx() {
    if [[ $3 =~ ^[0-9]+(\.[0-9]+)+$ ]] && [ "$(printf '%s\n' $NGINX_MIN "$3" | sort -V | head -1)" = $NGINX_MIN ]; then
        echo "ok   $1 $2: $3"
    else
        echo "FAIL $1 $2: '$3' is not nginx $NGINX_MIN or later"; rc=1
    fi
}
for image in nginx-photon harbor-portal; do
    check_nginx $image "nginx -v" "$(docker run --rm --entrypoint nginx goharbor/$image:$TAG -v 2>&1 | sed -n 's#^nginx version: nginx/##p')"
    check_nginx $image "rpm database" "$(docker run --rm --user root --entrypoint tdnf goharbor/$image:$TAG --disablerepo='*' list installed nginx 2>&1 \
        | sed -n 's/^nginx\.[^ ]* *\([0-9]*:\)\{0,1\}\([0-9][0-9.]*\)-.*/\2/p')"
done
exit $rc
