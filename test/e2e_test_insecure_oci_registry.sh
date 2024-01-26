#!/usr/bin/env bash
#
# Copyright 2023 The Sigstore Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

go build -o cosign ./cmd/cosign
tmp=$(mktemp -d)
cp cosign $tmp/

INSECURE_REGISTRY_NAME=${INSECURE_OCI_REGISTRY_NAME:-insecure-oci-registry.notlocal}
INSECURE_REGISTRY_PORT=${INSECURE_OCI_REGISTRY_PORT:-5002}

pushd $tmp

pass="$RANDOM"
export COSIGN_PASSWORD=$pass
export COSIGN_YES="true"
export COSIGN_EXPERIMENTAL=1

./cosign generate-key-pair
signing_key=cosign.key
verification_key=cosign.pub

img="${INSECURE_REGISTRY_NAME}:${INSECURE_REGISTRY_PORT}/test"
(crane delete $(./cosign triangulate $img)) || true
crane cp ghcr.io/distroless/static $img --insecure

# Operations with insecure registries should fail by default, then succeed
# with `--allow-insecure-registry`
if (./cosign sign --key ${signing_key} $img); then false; fi
./cosign sign --allow-insecure-registry --registry-referrers-mode=oci-1-1 --key ${signing_key} $img
if (./cosign verify --key ${verification_key} $img); then false; fi
./cosign verify --allow-insecure-registry --experimental-oci11=true --key ${verification_key} $img

echo "SUCCESS"
