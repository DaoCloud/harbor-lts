#!/bin/bash
# The API tests download their charts from gs://harbor-builds, which no longer exists.
# Build stand-ins with the same names, versions and checked contents, and serve them
# from this host. usage: serve_test_charts.sh <ip>
set -e
IP=$1
PORT=8099
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT=/tmp/test-charts
rm -rf $ROOT && mkdir -p $ROOT/harbor-builds/bin/charts $ROOT/harbor-builds/helm-chart-test-files

# make_chart <name> <version> <description> <output dir>
make_chart() {
    work=$(mktemp -d)
    mkdir -p $work/$1/templates
    cat > $work/$1/Chart.yaml <<CHART
apiVersion: v1
name: $1
version: $2
appVersion: $2
description: $3
CHART
    echo "# $3" > $work/$1/README.md
    printf 'adminserver:\n  replicas: 1\n' > $work/$1/values.yaml
    cat > $work/$1/requirements.yaml <<REQ
dependencies:
- name: postgresql
  version: 0.8.3
  repository: https://kubernetes-charts.storage.googleapis.com
REQ
    echo "$1 $2" > $work/$1/templates/NOTES.txt
    tar -C $work -czf $4/$1-$2.tgz $1
    rm -rf $work
}

make_chart mariadb 4.3.1 "Fast, reliable, scalable, and easy to use open-source relational database system." $ROOT/harbor-builds/bin/charts
make_chart prometheus 7.0.2 "Prometheus is a monitoring system and time series database." $ROOT/harbor-builds/helm-chart-test-files
make_chart harbor 0.2.0 "An Enterprise-class Docker Registry by VMware. Helm Chart for Harbor" $ROOT/harbor-builds/helm-chart-test-files

nohup python3 -m http.server $PORT --directory $ROOT > /tmp/test-charts.log 2>&1 &
sleep 2
curl -fsS -o /dev/null http://$IP:$PORT/harbor-builds/helm-chart-test-files/harbor-0.2.0.tgz

grep -rl 'https://storage.googleapis.com/harbor-builds' $DIR/../apitests/python | while read f; do
    sed -i "s#https://storage.googleapis.com/harbor-builds#http://$IP:$PORT/harbor-builds#g" $f
    echo "test charts: rewrote $f"
done
