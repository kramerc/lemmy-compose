#!/bin/sh
mkdir -p volumes/pictrs
sudo chown -R 991:991 volumes/pictrs
docker compose up -d
