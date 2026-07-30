# Comprehensive HashiCorp Vault Setup, Helm Integration & Troubleshooting Guide

This guide provides an end-to-end reference for deploying HashiCorp Vault into a Kubernetes cluster using Helm, configuring the **Kubernetes Authentication Method**, mounting dynamic secrets into the Todo API application, and troubleshooting all potential issues based on real-world integration experience.

---

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Namespace: vault                                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ HashiCorp Vault Server (ClusterIP: vault.vault.svc.cluster.local:8200)│  │
│  │ Secret KV Path: secret/data/todo-app                                  │  │
│  │ Auth Method: auth/kubernetes (Role: todo-api-role)                     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────▲──────────────────────────────────────┘
                                       │ Kubernetes Token Auth & Secret Read
┌──────────────────────────────────────┴──────────────────────────────────────┐
│ Namespace: todo-app                                                         │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ ServiceAccount: todo-api                                              │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │ Mounts ServiceAccount Token          │
│  ┌───────────────────────────────────▼───────────────────────────────────┐  │
│  │ Pod: api-deployment                                                   │  │
│  │  ┌─────────────────────────┐     ┌─────────────────────────────────┐  │  │
│  │  │ Init/Sidecar Container  │     │ App Container (api)             │  │  │
│  │  │ (vault-agent)           ├────►│ Shared Volume: /vault/secrets   │  │  │
│  │  │ Authenticates & Fetches │     │ Shell Wrapper: . /vault/secrets │  │  │
│  │  └─────────────────────────┘     └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Install HashiCorp Vault in Kubernetes via Helm

Run the following command to deploy Vault in development mode in the `vault` namespace with the **Vault Agent Injector** enabled:

```bash
# Add HashiCorp Helm Repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault in dev mode inside namespace 'vault'
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true"
```

---

## Step 2: Prepare Application Namespace & ServiceAccount

Ensure the `todo-app` namespace and the `todo-api` ServiceAccount exist:

```bash
# Create application namespace
kubectl create namespace todo-app --dry-run=client -o yaml | kubectl apply -f -

# Create ServiceAccount for API deployment
kubectl create serviceaccount todo-api -n todo-app --dry-run=client -o yaml | kubectl apply -f -
```

---

## Step 3: Configure Kubernetes Authentication & Policy in Vault

Exec into the Vault server pod (`vault-0` in `vault` namespace) to configure secrets, policies, and Kubernetes authentication:

```bash
# Exec into Vault server pod
kubectl exec -it vault-0 -n vault -- sh

# 1. Enable Key-Value (KV v2) secrets engine
# Note: In Vault Dev mode ('server.dev.enabled=true'), 'secret/' is already enabled.
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "secret/ path already enabled"

# 2. Write database and JWT credentials to Vault KV path 'secret/todo-app'
vault kv put secret/todo-app \
  db_password="root_password" \
  jwt_secret="SuperSecretKeyForTodoAppAuthJWTToken2026"

# 3. Create a policy allowing Todo API to read secrets
printf 'path "secret/data/todo-app" {\n  capabilities = ["read"]\n}\n' | vault policy write todo-api-policy -

# 4. Enable Kubernetes Authentication Method
vault auth enable kubernetes 2>/dev/null || echo "kubernetes auth method already enabled"

# 5. Configure Vault to talk to local Kubernetes API server
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# 6. Create Vault Auth Role mapping Kubernetes ServiceAccount 'todo-api' in 'todo-app' namespace to 'todo-api-policy'
vault write auth/kubernetes/role/todo-api-role \
  bound_service_account_names=todo-api \
  bound_service_account_namespaces=todo-app \
  policies=todo-api-policy \
  ttl=24h
```

---

## Step 4: Configure Helm Chart Values for Vault Injection

In `helm/values-settings.yaml`, add the Vault annotations and container startup wrapper command under `components.api`:

```yaml
components:
  api:
    enabled: true
    name: todo-api
    deploymentName: api-deployment
    serviceName: todo-web-api
    serviceAccountName: todo-api
    podAnnotations:
      vault.hashicorp.com/agent-inject: "true"
      vault.hashicorp.com/role: "todo-api-role"
      vault.hashicorp.com/vault-address: "http://vault.vault.svc.cluster.local:8200"
      vault.hashicorp.com/agent-inject-secret-secrets: "secret/data/todo-app"
      vault.hashicorp.com/agent-inject-template-secrets: |
        {{- with secret "secret/data/todo-app" -}}
        export DB_PASSWORD="{{ .Data.data.db_password }}"
        export JWT_SECRET="{{ .Data.data.jwt_secret }}"
        export DB_CONNECTION_STRING="Server=mysql-service;Port=3306;Database=todo_db;User=root;Password={{ .Data.data.db_password }};"
        {{- end -}}
    command: ["/bin/sh", "-c"]
    args: ["if [ -f /vault/secrets/secrets ]; then set -a; . /vault/secrets/secrets; set +a; fi; exec dotnet TodoApi.dll"]
    image:
      repository: todo-backend
      tag: latest
```

---

## Step 5: Deploy & Verify Release

Deploy the application using Helm:

```bash
# Upgrade / Install release
helm upgrade --install todo ./helm -n default \
  -f helm/values-common.yaml \
  -f helm/values-settings.yaml \
  -f helm/values-secrets.yaml

# Verify pod status (should show 2/2 containers running)
kubectl get pods -n todo-app

# Inspect injected secrets mounted inside the API container
kubectl exec deploy/api-deployment -n todo-app -c api -- cat /vault/secrets/secrets

# Check API application logs
kubectl logs deploy/api-deployment -n todo-app -c api
```

---

## Session Integration Issues & Solutions Log

Below are all the real-world errors and issues encountered during this integration session and how each was resolved:

### 1. `appsettings.json` Misplaced JSON Hierarchy
- **Error**: `.GetConnectionString("DefaultConnection")` returned `null` during local startup.
- **Cause**: `ConnectionStrings` and `Jwt` blocks were accidentally nested **inside** the `"Logging"` JSON block in `appsettings.json`.
- **Solution**: Re-structured `appsettings.json` so `ConnectionStrings` and `Jwt` reside at the root level of the JSON document, with empty string placeholders `""`.

### 2. Hardcoded Secret Fallbacks in Code
- **Problem**: `Program.cs` contained hardcoded strings `"root_password"` and `"SuperSecretKeyForTodoAppAuthJWTToken2026"`.
- **Impact**: Masked missing environment variables silently instead of failing fast.
- **Solution**: Removed all hardcoded secret strings and added explicit `InvalidOperationException` checks if secrets are missing on startup.

### 3. Vault Dev Mode KV Mount Conflict (`path is already in use at secret/`)
- **Error**: `Code: 400. Errors: * path is already in use at secret/`.
- **Cause**: Running `vault secrets enable -path=secret kv-v2` in Vault Dev Mode (`server.dev.enabled=true`), where `secret/` is mounted automatically at server startup.
- **Solution**: Wrapped command with conditional fallback: `vault secrets enable -path=secret kv-v2 2>/dev/null || echo "secret/ path already enabled"`.

### 4. Vault Agent 403 Forbidden (`service account name not authorized`)
- **Error**: Log in `vault-agent-init`:
  `URL: PUT http://vault.vault.svc:8200/v1/auth/kubernetes/login Code: 403. Errors: * service account name not authorized`.
- **Cause**: Pod was running with `serviceAccountName: default` because the library chart template `_deployment.tpl` lacked support for rendering `serviceAccountName`.
- **Solution**: Updated `_deployment.tpl` to render `serviceAccountName: {{ $val.serviceAccountName }}` and set `serviceAccountName: todo-api` in `values-settings.yaml`.

### 5. Helm Ownership Validation Mismatch (`Secret "todo-secrets" in namespace "todo-app" exists...`)
- **Error**: `Error: unable to continue with install: Secret "todo-secrets" ... key "meta.helm.sh/release-name" must equal "todo-app": current value is "todo"`.
- **Cause**: Attempting to run `helm upgrade todo-app` when the existing deployed release name was `todo` in namespace `default`.
- **Solution**: Ran upgrade using the matching release name and namespace: `helm upgrade todo ./helm -n default -f ...`.

### 6. Library Chart Template Missing `command` & `args`
- **Problem**: Pod spec ignored container entrypoints defined in `values-settings.yaml`.
- **Cause**: `_deployment.tpl` did not template `command:` or `args:` arrays.
- **Solution**: Added `command` and `args` templating logic under `containers:` in `_deployment.tpl`.

### 7. Helm Template Syntax Error (`unexpected EOF` / `nil pointer evaluating interface {}.claimName`)
- **Error**: `Error: parse error at (_deployment.tpl:127): unexpected EOF` and `nil pointer evaluating interface {}.claimName`.
- **Cause**: Unclosed `{{- if }}` block in `imagePullSecrets` and bad template path `.Values.components.db.persistence.claimName`.
- **Solution**: Properly closed `imagePullSecrets` block with `{{- end }}` and referenced `"mysql-pvc"` directly.

### 8. C# Variable Shadowing Compiler Error (`CS0136: A local or parameter named 'key' cannot be declared in this scope`)
- **Error**: `error CS0136: A local or parameter named 'key' cannot be declared in this scope because that name is used in an enclosing local scope`.
- **Cause**: `var key = parts[0]...` in the secret parsing loop shadowed `var key = Encoding.UTF8.GetBytes(jwtSecret)` declared later in `Program.cs`.
- **Solution**: Renamed the loop variable to `var envKey`.

### 9. Empty Environment Variable Overriding (`Access denied for user 'root'@'localhost' (using password: NO)`)
- **Error**: Backend crashed with `Access denied for user 'root'@'localhost' (using password: NO)`.
- **Cause**:
  1. Static container `envVars` set `DB_CONNECTION_STRING` with empty `$(DB_PASSWORD)` (`Password=;`).
  2. The C# null-coalescing operator `??` evaluated `""` (empty string) as non-null, preventing fallback logic from running.
- **Solution**:
  1. Removed static secret `envVars` from container spec when Vault is enabled.
  2. Injected container shell wrapper in `args`: `if [ -f /vault/secrets/secrets ]; then set -a; . /vault/secrets/secrets; set +a; fi; exec dotnet TodoApi.dll`.
  3. Created helper `GetConfigValue(key)` in `Program.cs` using `string.IsNullOrWhiteSpace` to filter out empty strings.

### 10. MySQL PVC Lock Conflict (`Unable to lock ./ibdata1 error: 11`)
- **Error**: `[ERROR] [InnoDB] Unable to lock ./ibdata1 error: 11`.
- **Cause**: Old orphan MySQL pod was still running and holding the lock on `mysql-pvc` when a new pod started.
- **Solution**: Force deleted old orphan pod: `kubectl delete pod <old-pod-name> -n todo-app --force --grace-period=0`.
