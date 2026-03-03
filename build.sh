#!/bin/bash

set -e

IMAGE_NAME="tshark"
TAG="latest"

# Ensure the multi-platform builder exists and is active
docker buildx inspect multiarch-builder >/dev/null 2>&1 ||
    docker buildx create --name multiarch-builder --driver docker-container --bootstrap

docker buildx use multiarch-builder

docker buildx build \
    --platform linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/386,linux/ppc64le,linux/riscv64,linux/s390x \
    --tag "${IMAGE_NAME}:${TAG}" \
    --load \
    .
