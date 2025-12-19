#!/bin/bash
set -e

echo "Pulling base image..."
docker pull ghcr.io/astral-sh/uv:debian

echo "Building image..."
docker build -t tools-image .

echo "Scanning image..."
trivy image tools-image