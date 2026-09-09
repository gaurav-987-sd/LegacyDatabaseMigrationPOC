# CI/CD Setup — Terraform + AKS (Windows) + ArgoCD + cert-manager

## What changed vs. your original Terraform

- `modules/aks`: added a Windows node pool, switched networking from `kubenet` to
  `azure` CNI (Windows nodes require this — cannot run Windows containers on
  kubenet), and enabled OIDC issuer + Workload Identity.
- `envs/dev/main.tf`: wired the above, added a User Assigned Identity +
  federated credential (so pods can read Key Vault without stored secrets),
  granted that identity + the CI service principal access to Key Vault / ACR.
- New: two GitHub Actions workflows, Kubernetes manifests, ArgoCD
  Applications, and a cert-manager ClusterIssuer.
- The original `app-service` module (Azure App Service / PaaS) is left in
  place but is **not used** by this AKS path — delete it if you're going
  100% AKS, or keep it as a side-by-side comparison environment.

## Why Deployment, not StatefulSet

Your app's data lives in PostgreSQL, not on the pod. That makes every pod
interchangeable — any pod can serve any request because the database is the
single source of truth. A plain `Deployment` with `replicas: 2` is correct
here; a `StatefulSet` would only be needed if pods held their own local data
that had to stay tied to a specific pod identity, which isn't the case.

## Why cert-manager instead of a "daemon service" for certs

cert-manager is a normal Deployment (a few controller pods) that watches
every `Ingress` with a `cert-manager.io/cluster-issuer` annotation and
issues/renews its TLS cert automatically. One install covers **every**
service in the cluster — you don't create a per-service or per-node daemon;
you just add that one annotation to each Ingress (already done in
`k8s/base/ingress.yaml`).

## One-time setup, in order

### 1. Create the Terraform state storage account (once, manually)

You already have `rg-tfstate`. Create a storage account inside it:

```powershell
az storage account create `
  --name legacydbmigtfstate `
  --resource-group rg-tfstate `
  --location centralus `
  --sku Standard_LRS

az storage container create `
  --account-name legacydbmigtfstate `
  --name tfstate `
  --auth-mode login
```

Put the real storage account name into `terraform/envs/dev/backend.hcl`
(replace `CHANGE-ME-tfstateacct`).

### 2. Create a service principal for CI

```powershell
az ad sp create-for-rbac --name "github-actions-legacydbmig" `
  --role contributor `
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

This prints `appId` (→ `AZURE_CLIENT_ID`), `password` (→
`AZURE_CLIENT_SECRET`), `tenant` (→ `AZURE_TENANT_ID`). Get its object ID too
(different from appId — needed for the ACR role assignment in Terraform):

```powershell
az ad sp show --id <appId> --query id -o tsv
```

Put that value into `terraform.tfvars` as `ci_service_principal_object_id`.

### 3. Add GitHub repo secrets

Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | `appId` from step 2 |
| `AZURE_CLIENT_SECRET` | `password` from step 2 |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |
| `AZURE_TENANT_ID` | `tenant` from step 2 |
| `WINDOWS_ADMIN_PASSWORD` | a strong password for the AKS Windows nodes |

### 4. Fill in `terraform/envs/dev/terraform.tfvars`

Copy from `terraform.tfvars.example`, fill in `ci_service_principal_object_id`.
Everything else has sensible defaults — change VM sizes only if Azure
rejects them for your subscription/region (same error you hit before; check
allowed sizes with `az vm list-skus --location centralus --size Standard_D --output table`).

### 5. Run the Terraform workflow

Push these files to `main` (or open a PR first to see the plan). The
`terraform.yml` workflow applies on merge to `main`. Watch the Actions tab.

### 6. Enable the Key Vault CSI add-on (one-time, after the cluster exists)

Terraform provisions the cluster and identity, but the AKS **add-on** itself
needs to be turned on once:

```powershell
az aks enable-addons --addons azure-keyvault-secrets-provider `
  --resource-group rg-legacydbmig-dev `
  --name <aks_cluster_name-from-terraform-output>
```

### 7. Install ArgoCD (one-time, if not already running)

If ArgoCD isn't already installed somewhere Rancher manages:

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

If ArgoCD instead runs centrally on your Rancher local cluster and manages
this AKS cluster as a **downstream/imported cluster**, first import this AKS
cluster into Rancher (Rancher UI → Cluster Management → Import Existing →
follow the generated `kubectl apply` command), then in each `argocd/*.yaml`
Application file, change `destination.server` from
`https://kubernetes.default.svc` to the registered cluster's server URL (or
`name: <cluster-name>` if using ArgoCD cluster names) as shown in your
ArgoCD cluster list.

### 8. Fill in the placeholders and apply the ArgoCD Applications

After `terraform apply` finishes, run:

```powershell
terraform output
```

Use those values to replace every `CHANGE-ME...` in:
- `k8s/base/serviceaccount.yaml` (workload identity client ID)
- `k8s/base/secretproviderclass.yaml` (client ID, Key Vault name, tenant ID)
- `k8s/base/deployment.yaml` (ACR name)
- `k8s/base/kustomization.yaml` (ACR name)
- `k8s/base/ingress.yaml` (your real domain)
- `cert-manager/cluster-issuer.yaml` (your email)
- `argocd/*.yaml` (repo URL, if different from the default)

Commit and push, then apply the ArgoCD Applications once:

```powershell
kubectl apply -f argocd/ingress-nginx-app.yaml
kubectl apply -f argocd/cert-manager-app.yaml
kubectl apply -f argocd/cluster-issuer-app.yaml
kubectl apply -f argocd/app-legacydbmig.yaml
```

From here on, every push to `main` that touches app code triggers
`build-and-deploy.yml`, which builds the Windows image, pushes it to ACR,
and commits the new tag — ArgoCD picks that commit up automatically and
rolls out the new pods. No manual `kubectl` deploys needed again.

### 9. Point DNS at the ingress

```powershell
kubectl get service -n ingress-nginx ingress-nginx-controller
```

Take the `EXTERNAL-IP` and point your domain's A record at it. cert-manager
issues the cert automatically once DNS resolves and the Ingress is live.
