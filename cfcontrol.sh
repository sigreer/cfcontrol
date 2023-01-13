#!/bin/bash
## Cloudflare Control Script for the management of domains using Cloudflare's API
source ./.env
source ./.secrets
for domain in $(cat domains.txt); do \
  curl -X POST -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_API_EMAIL" \
  -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/zones" \
  --data '{"account": {"id": "'$ACCOUNT_ID'"}, "name":"'$domain'","jump_start":true}'; done