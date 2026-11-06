#!/usr/bin/env bash
# Creates the Azure resources for GradeCalc and connects them to GitHub Actions.
# Safe to re-run. Requires: az login, gh auth login.
#
#   GITHUB_REPO=<owner>/<repo> ./infra/provision.sh
#
# Azure for Students subscriptions allow only some regions and VM sizes. List them with:
#   az policy assignment list --query "[].parameters"
# If creation is refused, set LOCATION and/or NODE_SIZE and run again.
set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:?Set GITHUB_REPO to owner/repo}"
LOCATION="${LOCATION:-indiasouthcentral}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-gradecalc}"
AKS_CLUSTER="${AKS_CLUSTER:-aks-gradecalc}"
NODE_SIZE="${NODE_SIZE:-Standard_B2s}"
APP_NAME="${APP_NAME:-gh-gradecalc-deployer}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# ACR names are globally unique, so derive a stable suffix from the subscription.
ACR_NAME="${ACR_NAME:-acrgradecalc${SUBSCRIPTION_ID:0:8}}"

echo "==> Registering resource providers"
for provider in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.Compute Microsoft.Network; do
  az provider register --namespace "$provider" --wait
done

echo "==> Resource group $RESOURCE_GROUP in $LOCATION"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "==> Container registry $ACR_NAME"
az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic \
  --admin-enabled false --output none
ACR_ID=$(az acr show --name "$ACR_NAME" --query id -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)

echo "==> AKS cluster $AKS_CLUSTER (takes 5-10 minutes)"
if ! az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --output none 2>/dev/null; then
  az aks create --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
    --tier free --node-count 1 --node-vm-size "$NODE_SIZE" \
    --attach-acr "$ACR_NAME" --no-ssh-key --output none
fi
AKS_ID=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --query id -o tsv)

echo "==> Identity for GitHub Actions: $APP_NAME"
CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)
if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
fi
az ad sp show --id "$CLIENT_ID" --output none 2>/dev/null || az ad sp create --id "$CLIENT_ID" --output none
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)

# Only workflows running on main of this repository can use the identity.
CREDENTIAL_NAME=github-main
# Ask GitHub for the subject prefix: it can include the numeric owner and repository
# IDs, in which case it stops matching if the repository is recreated under the same name.
SUBJECT_PREFIX=$(gh api "repos/$GITHUB_REPO/actions/oidc/customization/sub" --jq .sub_claim_prefix)
SUBJECT="${SUBJECT_PREFIX}:ref:refs/heads/main"
az ad app federated-credential delete --id "$CLIENT_ID" --federated-credential-id "$CREDENTIAL_NAME" 2>/dev/null || true
az ad app federated-credential create --id "$CLIENT_ID" --output none --parameters "{
  \"name\": \"$CREDENTIAL_NAME\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"$SUBJECT\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"

echo "==> Least-privilege role assignments"
assign_role() {
  az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
    --role "$1" --scope "$2" --output none
}
assign_role AcrPush "$ACR_ID"
assign_role "Azure Kubernetes Service Cluster User Role" "$AKS_ID"

echo "==> GitHub repository settings"
gh secret set AZURE_CLIENT_ID --repo "$GITHUB_REPO" --body "$CLIENT_ID"
gh secret set AZURE_TENANT_ID --repo "$GITHUB_REPO" --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --repo "$GITHUB_REPO" --body "$SUBSCRIPTION_ID"
gh variable set ACR_NAME --repo "$GITHUB_REPO" --body "$ACR_NAME"
gh variable set ACR_LOGIN_SERVER --repo "$GITHUB_REPO" --body "$ACR_LOGIN_SERVER"
gh variable set AKS_CLUSTER --repo "$GITHUB_REPO" --body "$AKS_CLUSTER"
gh variable set AKS_RESOURCE_GROUP --repo "$GITHUB_REPO" --body "$RESOURCE_GROUP"

echo "==> Done. Registry: $ACR_LOGIN_SERVER, cluster: $AKS_CLUSTER"
