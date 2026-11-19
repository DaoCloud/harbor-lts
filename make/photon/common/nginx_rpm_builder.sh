#!/bin/bash
# Builds nginx 1.30.7 as a Photon RPM for the nginx and portal base images, because Photon 5.0
# does not ship it yet. nginx 1.30.7 fixes the NGINX2Root vulnerabilities
# (https://nginx.org/en/security_advisories.html). The RPM is built from Photon's own nginx.spec
# with only Version, Release and changelog changed, so the rpm database records nginx 1.30.7
# and scanners see the real version. Release 0.1 sorts below Photon's own 1.30.7-1, so once Photon
# publishes that, tdnf installs Photon's package instead of this one.
#
# To remove this workaround once `tdnf list nginx` on photon:5.0 shows 1.30.7-1.ph5 or later:
# delete this script and, in make/photon/nginx/Dockerfile.base and make/photon/portal/Dockerfile.base,
# the nginx-rpm stage, the COPY --from=nginx-rpm line and the nginx-local repository lines.
#
# usage: nginx_rpm_builder.sh <dir>; runs in the photon image and turns <dir> into a local
# repository that holds the nginx RPM.
set -euo pipefail

out=$1
version=1.30.7
# The latest vmware/photon commit on branch 5.0 that changed SPECS/nginx (nginx 1.30.6-1.ph5)
photon_commit=9247ceb54281049e853b9780f0cde1d49646be53
top=/tmp/rpmbuild

tdnf install -y rpm-build createrepo_c coreutils sed tar gzip diffutils patch findutils gawk \
    gcc make binutils glibc-devel linux-api-headers libxcrypt-devel zlib-devel curl ca-certificates \
    openssl-devel pcre2-devel which systemd systemd-devel systemd-rpm-macros libxml2-devel libxslt-devel >> /dev/null

mkdir -p $top/SOURCES $top/SPECS "$out"
cd $top/SOURCES
fetch() {
    curl -fsSL --retry 5 --retry-all-errors --connect-timeout 30 -o "$1" "$2"
}
for f in nginx.spec nginx.service nginx.sysusers license.txt convert-to-dynamic.patch; do
    fetch $f https://raw.githubusercontent.com/vmware/photon/$photon_commit/SPECS/nginx/$f
done
fetch nginx-$version.tar.gz https://nginx.org/download/nginx-$version.tar.gz
fetch nginx-njs-0.9.9.tar.gz https://github.com/nginx/njs/archive/refs/tags/0.9.9.tar.gz
fetch headers-more-nginx-module-0.39.tar.gz https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v0.39.tar.gz

# nginx-1.30.7.tar.gz: the release whose nginx.org signature (Sergey Kandaurov's key
# D6786CE303D9A9022998DC6CC8464D549AF75C0A) was verified. njs and headers-more: archive_sha512sum
# from SPECS/nginx/config.yaml in the same Photon commit. The other files are that commit's blobs.
sha512sum -c <<EOF
c88979d6c4da0942110b2b78a5d1a4c62a3f1d943ec0a430f17df8f5d23c32620af44dc53569aac4f4fdd76a7a019dc97d7f994b87203ec35eafc9af8bc78555  nginx-$version.tar.gz
67b921c127fabb0ac0a8e53f63291af3227db0d2a9d67f32bfc853072403d9634f19ef736513a4007673fc98e1d3be8a5b3ac4832b04956852e43706891c38be  nginx-njs-0.9.9.tar.gz
b73099bc1d088afc2ccb13e97ad8dd2210cdb6c8355b348007042f23c4bb3ec239e9521f29cb4e82d09b930d8b6a46ccdc7fb75438bf180342d8c53727971c1e  headers-more-nginx-module-0.39.tar.gz
b71c7cc73a2996977e92cd67e7bc43dbd0e3e12cb88791fab2a9345f0c26e3ea9f00bb1eb68f96303b3cb87efb15869925f63043bf335a765f19b3d13dbbcda9  nginx.spec
2337a7123328c085a661a65fcb70b370f6823e70f7f6a3a3cb872f4d660bed1bd7eb86ca922c07b717dbc0d3d700911243045163595835a3ce6e3db8fe8508b2  nginx.service
acbcf59914e0fbbf2bbbd71dc9acedbc7f64e4bf4080c6aa2903548d1bf45556d62222b60a79b69071e5b36bfdae6547920bb1945c148b96e6579cac0f8c2fd0  nginx.sysusers
3489a9329b7f6b8e9a3a7b925751e835180ba04fc8eff098380772df8bba748d4896df3ba1f6c2d7f0b803a205e71164403fc07f7f9ec3e27db314bc9735f5fb  license.txt
5cd746f3ce47aceaf87939d64156c624ef5f4d1197aca07ab6881c44483f480668ce06ea90f7fea583de6dfbc4a931cee95b14aba622080dc018dc42887573ad  convert-to-dynamic.patch
EOF

{
    sed -e "s/^Version:.*/Version:        $version/" -e 's/^Release:.*/Release:        0.1%{?dist}/' \
        -e '/^%changelog/q' nginx.spec
    printf '* Thu Nov 19 2026 Harbor LTS - %s-0.1\n- Upgrade to %s for NGINX2Root, built from the 1.30.6-1 spec\n' $version $version
    sed '1,/^%changelog/d' nginx.spec
} > $top/SPECS/nginx.spec

. /etc/os-release
rpmbuild -bb --define "_topdir $top" --define "dist .ph${VERSION_ID%%.*}" --define 'debug_package %{nil}' \
    $top/SPECS/nginx.spec > $top/build.log 2>&1 || { tail -n 100 $top/build.log; exit 1; }
cp $top/RPMS/$(uname -m)/nginx-$version-0.1.*.rpm "$out"/
createrepo_c "$out"
rm -rf $top
