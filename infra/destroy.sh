#!/usr/bin/env bash
# Deletes everything provision.sh created so the subscription stops being charged.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-gradecalc}"
APP_NAME="${APP_NAME:-gh-gradecalc-deployer}"

read -r -p "Delete resource group $RESOURCE_GROUP and app $APP_NAME? Type yes: " answer
[ "$answer" = "yes" ] || { echo "Cancelled"; exit 1; }

CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)
[ -z "$CLIENT_ID" ] || az ad app delete --id "$CLIENT_ID"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion started. Check progress with: az group show --name $RESOURCE_GROUP"
