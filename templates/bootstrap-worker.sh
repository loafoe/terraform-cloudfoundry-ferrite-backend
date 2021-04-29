#!/usr/bin/env bash
set -x

# Start from a known state
docker volume create worker || true


# Copy config file using ubuntu container
docker kill ubuntu || true
docker rm ubuntu || true
docker run --name=ubuntu -d -v worker:/work ubuntu:latest
docker cp /home/${user}/local.yml ubuntu:/work/local.yml
docker kill ubuntu || true
docker rm ubuntu || true

# Start ferrite worker container
docker kill worker || true
docker rm worker || true
docker run -d -v worker:/work -e CLOUD_FILE=/work/local.yml -e DOCKER_HOST=tcp://${private_ip}:2375 --name=worker --restart=always ${docker_image} /app/app worker

