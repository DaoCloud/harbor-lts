#!/bin/bash
set -x

set -e

sudo apt-get update && sudo apt-get install -y libldap2-dev
sudo go env -w GO111MODULE=auto
# Unpinned GOPATH-mode go get now resolves module versions this Go cannot build.
# The tests build in module mode, so only the tools are installed, at fixed versions.
go install golang.org/x/lint/golint@v0.0.0-20210508222113-6edffad5e616
go install github.com/GeertJohan/fgt@v0.0.0-20160120143236-262f7b11eec0
go install github.com/mattn/goveralls@v0.0.11
go install github.com/client9/misspell/cmd/misspell@v0.3.4
# binary will be $(go env GOPATH)/bin/golangci-lint
# go install/go get installation aren't guaranteed to work. We recommend using binary installation.
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.45.2
sudo service postgresql stop || echo no postgresql need to be stopped
sleep 2

sudo rm -rf /data/* 
# golangci-lint v1.45.2 in go_check cannot analyze Go 1.27 code; generate the API code the tests need.
sudo -E env "PATH=$PATH" make gen_apis
sudo ./tests/hostcfg.sh
sudo ./tests/generateCerts.sh
sudo make build -e BUILDTARGET="_build_db _build_registry _build_prepare" -e PULL_BASE_FROM_DOCKERHUB=false -e BUILDBIN=true
docker run --rm -v /:/hostfs:z goharbor/prepare:dev gencert -p /etc/harbor/tls/internal
sudo MAKEPATH=$(pwd)/make ./make/prepare
sudo mkdir -p "/data/redis"
sudo mkdir -p /etc/core/ca/ && sudo mv ./tests/ca.crt /etc/core/ca/
sudo mkdir -p /harbor && sudo mv ./VERSION /harbor/UIVERSION
sudo ./tests/testprepare.sh

cd tests && sudo ./ldapprepare.sh && cd ..
env
docker images
sudo sed -i 's/__version__/dev/g' ./make/docker-compose.test.yml
cat ./make/docker-compose.test.yml
sudo mkdir -p ./make/common/config/registry/ && sudo mv ./tests/reg_config.yml ./make/common/config/registry/config.yml
sudo mkdir -p /storage && sudo chown 10000:10000 -R /storage
