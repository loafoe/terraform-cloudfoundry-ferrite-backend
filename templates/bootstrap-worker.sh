#!/usr/bin/env bash
set -x

# Start from a known state
docker volume create worker || true
docker kill worker || true
docker rm worker || true

# Copy config file using ubuntu container
docker run --name=ubuntu -d -v worker:/work ubuntu:latest
docker cp /home/${user}/local.yml ubuntu:/work/local.yml
docker kill ubuntu || true
docker run ubuntu || true

# Start ferrite worker container
docker run -d -v worker:/work -e CLOUD_FILE=/work/local.yml -e DOCKER_HOST=tcp://${private_ip}:2375 --name=worker --restart=always ${docker_image} /app/app worker

