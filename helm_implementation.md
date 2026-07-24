# Helm Migration Mentoring Notes

This document contains architectural decisions, mentoring notes, and best practices documented during the conversion of legacy Kubernetes manifests into an enterprise-grade Helm chart.

---

## Step 1: Migrate `api-deployment.yaml` -> `templates/deployment-api.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **Foundational Setup (`Chart.yaml` & `_helpers.tpl`)**: To initialize a Helm chart, we define the chart metadata (`Chart.yaml`) and create common helpers (`_helpers.tpl`) to standardize names, tags, and labels.
* **Component-Specific Selectors**: We defined selector labels in `_helpers.tpl` for each of our 3 components (`todo-api`, `todo-ui`, and `todo-mysql`).
* **Deployment Templating**: We replaced hardcoded values (like `image`, `replicaCount`, `ports`, `imagePullPolicy`, and the `DB_CONNECTION_STRING` database hosts) with Helm dynamic tags (`{{ .Values.api.image.repository }}`) so that we can easily customize details between environments (e.g., dev, staging, prod) without modifying the templates themselves.

#### 2. Where the values belong (and why)
* **`values-common.yaml`**: Contains `namespace`, `imagePullPolicy`, `ingress`, and `commonLabels`. These define the baseline infrastructure platform settings. They are environmental but apply to all containers in the chart.
* **`values-settings.yaml`**: Contains image repositories/tags, container port, and specific configuration settings (like `jwtIssuer`, `jwtAudience`, `enableSwagger`). These control how the application behaves functionally.
* **`values-secrets.yaml`**: Contains the JWT signing secret and the MySQL password. This prevents sensitive credentials from leaking into public Git repositories. In a real-world enterprise pipeline, this file would be encrypted using tools like **SOPS**, **Ansible Vault**, or fetched dynamically from **HashiCorp Vault** or **AWS Secrets Manager**.
* **`values-size.yaml`**: Contains `replicaCount` and container `resources` (requests and limits). Sizing needs to be completely separate because a development environment might only run 1 replica with minimal memory requests (e.g. `256Mi`), while a production environment might run 5 replicas with higher memory requests (e.g. `2Gi`).

#### 3. Enterprise Helm Practices
* **Label Isolation**: We decoupled standard metadata labels (which Helm appends dynamically like `helm.sh/chart` or `app.kubernetes.io/instance`) from the Pod selectors (`app: todo-api`).
* **Resource Declarations**: Standard enterprise charts **always** declare resource requests and limits. If resources are left unset, one misbehaving pod can consume all host memory/CPU, resulting in other pods being evicted (noisy neighbor problem).
* **Dynamic Connection Strings**: Instead of hardcoding the connection host/user/database, we templated the `DB_CONNECTION_STRING` using variable expansion:
  `Server={{ .Values.db.config.host }};Port={{ .Values.db.port }};...`
  This makes sure that if the MySQL database is moved out of Kubernetes to a managed cloud database (like AWS RDS or GCP Cloud SQL), the chart remains functional by simply changing the host value in `values-settings.yaml`.

#### 4. Common Mistakes
* **Immutable Selectors Mismatch**: A common junior DevOps mistake is attempting to update the legacy selector label `app: todo-api` to a modern standard (like `app.kubernetes.io/name: {{ include "todo-app.name" . }}`) directly in the template. In Kubernetes, **Deployment Selector fields are immutable**. Attempting to apply a selector change on an existing resource in a production cluster will result in a deployment failure.
* **Leaking Secrets**: Placing raw API keys or DB passwords in `values-settings.yaml` or `values-common.yaml`.

#### 5. Production DevOps Execution
In production team workflows:
* The `values-secrets.yaml` file is never stored in plain-text git. DevOps teams typically store secrets in **HashiCorp Vault** or use **SOPS** (Secrets Operations) to encrypt the secrets file with GPG or AWS KMS keys, only decrypting it during CI/CD execution.
* Helm chart templates are kept clean and generic, while environment folders hold different settings (e.g., `envs/dev/values-settings.yaml`, `envs/prod/values-size.yaml`).

---

## Step 2: Migrate `mysql-deployment.yaml` -> `templates/deployment-db.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **MySQL Deployment Templating**: Migrated the legacy MySQL deployment into a generic Helm template, exposing the port via `{{ .Values.db.port }}` and setting the image using repository and tag settings.
* **Volume Mapping Integration**: Kept the mapping to `mysql-pvc` intact to preserve data persistence across database restarts.

#### 2. Where the values belong (and why)
* **`values-settings.yaml`**: The database name `todo_db` and standard port `3306` belong in settings because they dictate how application services discover and connect to the database.
* **`values-secrets.yaml`**: The database root password belongs in secrets because it's a sensitive credential.
* **`values-size.yaml`**: The MySQL replica count (usually 1 for single-instance, but could be scaled or modified) and resource requests/limits (which are higher for DBs, e.g., 1Gi limit/512Mi request) belong here. MySQL is resource-heavy, so segregating sizing is critical for cluster scheduling.

#### 3. Enterprise Helm Practices
* **Stateful Applications Sizing**: Database instances in enterprise contexts require strict CPU and memory limits to prevent them from choking other services on the node during heavy query execution.
* **Storage Class Separation**: In advanced setups, the PVC storage class can be configured per environment (e.g., `gp3` in AWS, `standard` in GCP) via a helper, though here we inherit the cluster's default.

#### 4. Common Mistakes
* **Hardcoding DB Credentials**: Storing default root credentials like `root_password` directly in the deployment template.
* **Database Replicas scaling**: Scaling a database deployment's `replicas` above 1 without configuring database replication (like master-slave/Galera). Doing so with a shared Persistent Volume will corrupt the DB, or fail to mount.

#### 5. Production DevOps Execution
In production team workflows:
* We rarely host a standalone, single-instance database pod like this. Instead, enterprise teams use managed database services (e.g. AWS RDS) or deploy database clusters using specialized **Kubernetes Operators** (like the Oracle MySQL Operator or CloudNativePG for Postgres) to handle replication, backups, and failovers automatically.

---

## Step 3: Migrate `ui-deployment.yaml` -> `templates/deployment-ui.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **UI Deployment Templating**: Migrated the legacy UI deployment into a generic Helm template, exposing the container port via `{{ .Values.ui.port }}` and setting the image using repository and tag settings.
* **Metadata Alignment**: Attached common Helm labels and selector labels while preserving the original `app: todo-ui` selector so that existing workloads update seamlessly.

#### 2. Where the values belong (and why)
* **`values-settings.yaml`**: The UI port `80` and the image repository/tag details belong here.
* **`values-size.yaml`**: The replica count and the resource requests/limits (CPU and Memory) belong in sizing. Since the UI is a static Single Page Application (SPA) served via Nginx, it consumes significantly fewer resources compared to the backend and database. We allocate lower limits (e.g., `200m` CPU and `256Mi` Memory) to optimize cluster utilization.

#### 3. Enterprise Helm Practices
* **SPA Optimization**: For Nginx serving Angular/React, memory usage is very stable and low. Setting appropriate limits allows Kubernetes to pack these pods efficiently (high density).

#### 4. Common Mistakes
* **Over-allocating Resources for SPAs**: Assigning high resource limits to frontend servers that are just serving static files. This wastes cluster resources.

#### 5. Production DevOps Execution
In production team workflows:
* Frontend static files are frequently served via a Content Delivery Network (CDN) like Cloudflare, AWS CloudFront, or Fastly, instead of running inside Kubernetes pods. This minimizes latency and reduces the load/cost of the Kubernetes cluster.

---

## Step 4: Migrate `api-service.yaml` -> `templates/service-api.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **Service Name Preservation**: Preserved the name `todo-web-api` exactly. The Service name is vital because the Nginx reverse-proxy on the frontend pod is hardcoded to proxy API traffic to `http://todo-web-api:5000`.
* **Port Customization**: Dynamically mapped the ports to match the API settings (`{{ .Values.api.port }}`).

#### 2. Where the values belong (and why)
* **`values-common.yaml`**: The service type `ClusterIP` belongs in common infrastructure. Since this service is purely accessed internally by the frontend Nginx pod in the same namespace, a private cluster IP is sufficient.
* **`values-settings.yaml`**: The port number `5000` belongs in settings because it describes the app configuration.

#### 3. Enterprise Helm Practices
* **Service Type Overrides**: In development environments, DevOps engineers might override the service type to `NodePort` or `LoadBalancer` for easier developer debugging, whereas in production it is strictly locked down to `ClusterIP`.

#### 4. Common Mistakes
* **Breaking In-Cluster DNS**: Changing the name of the service (e.g., adding `{{ include "todo-app.fullname" . }}` helper to the Service name) without updating the downstream consumers (like the Nginx `nginx.conf` proxy pass). This causes connection timeouts or `502 Bad Gateway` errors.

#### 5. Production DevOps Execution
In production team workflows:
* Services are monitored using Service Monitors in Prometheus. DevOps teams inject prometheus annotations (e.g. `prometheus.io/scrape: "true"`) into the Service metadata using configurable common values, which we support via `{{- toYaml .Values.commonLabels }}`.

---

## Step 5: Migrate `mysql-service.yaml` -> `templates/service-db.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **MySQL Service Name Preservation**: Kept the service name `mysql-service` exactly. This is required because the backend container `DB_CONNECTION_STRING` relies on DNS resolution of `mysql-service` to connect to MySQL.
* **Port Mapping**: Dynamically exposed port 3306 based on DB config variables.

#### 2. Where the values belong (and why)
* **`values-common.yaml`**: The service type `ClusterIP` belongs in common infrastructure settings.
* **`values-settings.yaml`**: The database port `3306` belongs in settings because it describes the app structure.

#### 3. Enterprise Helm Practices
* **No External Exposure for Databases**: Databases should never be exposed externally using `NodePort` or `LoadBalancer` services. They must strictly remain as `ClusterIP` to restrict database network traffic exclusively to inside the Kubernetes cluster.

#### 4. Common Mistakes
* **Exposing MySQL via Ingress or LoadBalancer**: Unknowingly configuring the database service to be public-facing, exposing the port to the internet.
* **Service Name Mismatch**: Modifying the database service name (e.g. using helper name) without modifying the connection string host parameter in the API deployment.

#### 5. Production DevOps Execution
In production team workflows:
* Internal networking is heavily secured. DevOps teams configure **Kubernetes NetworkPolicies** (network firewalls) to strictly allow incoming traffic to port 3306 on the MySQL pod *only* if the traffic originates from the `todo-api` pod.

---

## Step 6: Migrate `ui-service.yaml` -> `templates/service-ui.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **UI Service Name Preservation**: Preserved the name `ui-service` exactly. The Ingress manifest (`ingress.yaml`) uses this service name to route external HTTP traffic to the UI pod.
* **Port Customization**: Dynamically mapped the service port to `{{ .Values.ui.port }}`.

#### 2. Where the values belong (and why)
* **`values-common.yaml`**: The service type `ClusterIP` is defined here.
* **`values-settings.yaml`**: The UI service port `80` is configured insettings.

#### 3. Enterprise Helm Practices
* **Standardizing Service Ports**: Exposing web ports consistently on standard port `80` or secure port `443` inside the cluster, regardless of what port the application container is listening on. This decouples container network design from cluster network routing.

#### 4. Common Mistakes
* **Port Mismatches**: Unknowingly configuring `port` and `targetPort` incorrectly. The `port` is what the Service exposes inside the cluster, whereas `targetPort` must match the `containerPort` of the backend pod.

#### 5. Production DevOps Execution
In production team workflows:
* Frontend services can be exposed via NodePort or LoadBalancer directly if an Ingress Controller is not used. However, the best practice is to keep the service private (`ClusterIP`) and expose it *only* via an Ingress resource (acting as a reverse-proxy and SSL termination point).

---

## Step 7: Migrate `configmap.yaml` -> `templates/configmap.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **ConfigMap Templating**: Converted values like `JWT_ISSUER`, `JWT_AUDIENCE`, `RUN_MIGRATIONS`, and `ENABLE_SWAGGER` into dynamic fields evaluated via Helm settings.

#### 2. Where the values belong (and why)
* **`values-settings.yaml`**: ConfigMap contents belong entirely in settings since they are configuration settings that dictate behavior without compromising security.

#### 3. Enterprise Helm Practices
* **Quoting ConfigMap Values**: Always quote string values (e.g. `{{ .Values.api.config.jwtIssuer | quote }}`) in ConfigMaps. In Kubernetes, if a boolean or integer value is evaluated unquoted in a configmap (e.g. `RUN_MIGRATIONS: true` instead of `"true"`), Kubernetes will throw a validation error.

#### 4. Common Mistakes
* **Using ConfigMaps for Secrets**: Storing API keys, JWT secret keys, or database passwords in ConfigMaps instead of Secret resources.
* **Unquoted Booleans**: Forgetting to quote `true` / `false` values which causes `helm template` or `kubectl apply` to crash.

#### 5. Production DevOps Execution
In production team workflows:
* When configurations change in a ConfigMap, pods that mount those ConfigMaps as environment variables **do not automatically restart**. To resolve this, enterprise DevOps teams include a hash annotation of the ConfigMap inside the Pod template metadata in the Deployment (known as the **Configmap/Secret roll technique**):
  `checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}`
  This forces a rolling update of the pods whenever the configmap contents change.

---

## Step 8: Migrate `secret.yaml` -> `templates/secret.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **Secret Templating**: Extracted passwords and credentials to Helm variables, referencing them securely.
* **StringData Mapping**: Utilized `stringData` instead of base64-encoded `data`.

#### 2. Where the values belong (and why)
* **`values-secrets.yaml`**: The passwords and secrets (like DB credentials and JWT key) strictly reside in this file. It is the only location for sensitive credentials.

#### 3. Enterprise Helm Practices
* **Keep Secrets Out of Templates**: The main chart templates should never contain raw passwords, default testing credentials, or keys.
* **Automatic base64 Encoding**: Prefer using `stringData` in Helm secret templates, as it lets you inject plaintext variables that Kubernetes itself base64-encodes upon import. If you must use `data`, use the `b64enc` helper (e.g. `mysql-root-password: {{ .Values.db.rootPassword | b64enc }}`).

#### 4. Common Mistakes
* **Checking Secrets into Git**: Committing plaintext `values-secrets.yaml` files to git repositories.
* **Base64 Encoding Secrets manually in Values**: Forcing users to manually run `echo -n password | base64` to write values into the secrets file, which is prone to whitespace or trailing newline errors (e.g. using `echo` instead of `echo -n` adds a `\n` character, corrupting the password!).

#### 5. Production DevOps Execution
In production team workflows:
* Enterprise deployment pipelines use tools like **Helm Secrets** plugin, **SOPS**, or **Sealed Secrets** to encrypt the `values-secrets.yaml` file in Git. At deploy time, the CI/CD pipeline decrypts it or imports the values dynamically from a centralized vault (like Azure Key Vault or AWS Secrets Manager) using an init-container or CSI driver.

---

## Step 9: Migrate `pvc.yaml` -> `templates/pvc.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **PVC Size Templating**: Enabled dynamic definition of persistent storage requests (`{{ .Values.db.persistence.size }}`).
* **Storage Class Customization**: Dynamically mapped the `storageClassName` helper parameter so the database volume matches the specific hosting environment.

#### 2. Where the values belong (and why)
* **`values-common.yaml`**: The global `storageClass` parameter belongs here since it affects all PVCs in the chart.
* **`values-size.yaml`**: The database persistent disk size `2Gi` belongs in size, as storage capacity requirements differ dramatically between local development and large staging/production datasets.

#### 3. Enterprise Helm Practices
* **Dynamic Storage Provisioning**: Rely on Kubernetes StorageClasses to provision volumes on-demand (e.g. AWS EBS gp3, GCP pd-standard) rather than manually provisioning PersistentVolumes (PV) ahead of time. This ensures scalability and cloud provider compatibility.

#### 4. Common Mistakes
* **Hardcoding StorageClass**: Setting a specific storage class (e.g. `gp2`) directly in the PVC template, which causes failures when installing the chart on other clouds (like AKS or GCP GKE) or local clusters (like Minikube).
* **Shrinking Storage size**: Trying to decrease the PVC storage size in `values-size.yaml` on a running cluster. Kubernetes volume expansion is supported (increasing size), but shrinking a volume is **impossible** without deleting the PVC and losing database data.

#### 5. Production DevOps Execution
In production team workflows:
* PVCs are configured with `ReclaimPolicy: Retain` so that if a Helm release is accidentally uninstalled, the underlying storage disk in the cloud remains intact, safeguarding critical database files from catastrophic deletion.

---

## Step 10: Migrate `ingress.yaml` -> `templates/ingress.yaml`

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **Ingress Class Templating**: Parameterized the `ingressClassName` field to allow selecting different Ingress Controllers depending on the environment.
* **Service Port Dynamic Integration**: Sourced the backend service port number dynamically from `{{ .Values.ui.port }}`.

#### 2. Where the values belong (and why)
* **`values-common.yaml`**: The `ingress.className` setting (e.g. `nginx`) belongs here because it's a common cluster infrastructure platform setting.

#### 3. Enterprise Helm Practices
* **Ingress Class Standardization**: Standardize on `ingressClassName` instead of utilizing the deprecated `kubernetes.io/ingress.class` annotation. Modern Kubernetes clusters use the standard IngressClass API for routing.

#### 4. Common Mistakes
* **Deprecated Ingress API Versions**: Using older API versions like `extensions/v1beta1` or `networking.k8s.io/v1beta1` which are completely removed in modern Kubernetes versions (v1.22+). Always target `networking.k8s.io/v1`.
* **Path Type Mismatches**: Unknowingly omitting `pathType` or selecting an incorrect type like `Exact` when `Prefix` is required, causing static assets or route fallbacks to break.

#### 5. Production DevOps Execution
In production team workflows:
* Ingresses are rarely simple HTTP configurations. They include TLS certificates for SSL/HTTPS termination. In enterprise setups, Ingress manifests integrate with **cert-manager** via annotations (e.g., `cert-manager.io/cluster-issuer: letsencrypt-prod`) to automatically provision and rotate SSL certificates from Let's Encrypt.

---

## Step 11: Implement Startup, Liveness, and Readiness Probes

### Mentoring & DevOps Architectural Review

#### 1. Why these changes were made
* **Self-Healing Enablement**: Configured Startup, Liveness, and Readiness probes across all pods (API, UI, Database) so that Kubernetes can automatically detect deadlocks, handle traffic routing, and restart failed containers.
* **Slow-Start Management**: Implemented `startupProbe` to handle container bootstrapping (especially running database schema migrations on the API pod and initial table creation on the MySQL pod). This keeps liveness probes from prematurely killing the container before it finishes starting up.

#### 2. Where the values belong (and why)
* **`values-settings.yaml`**: The probe configs (initial delays, evaluation intervals, and failure thresholds) belong in settings because they are application configuration settings that developers and DevOps engineers tune based on how the application itself behaves and starts.

#### 3. Enterprise Helm Practices
* **Use Startup Probes for Migrations**: Never rely solely on a long `initialDelaySeconds` on the liveness probe to handle database migrations. If migrations take longer than expected, the liveness probe will timeout and restart the container, causing a boot-loop. Using a `startupProbe` with a high `failureThreshold` (e.g. 30 failures * 5s = 150s) gives the app plenty of time to boot while allowing faster failure detection once running.
* **Different Probe Actions**: Sourced HTTP GET probes for web endpoints (like port 80 Nginx) and TCP socket probes for database/API ports (like port 5000 and 3306) to match the appropriate endpoint protocol.

#### 4. Common Mistakes
* **Liveness Probe Mismatching Readiness Probe**: Pointing the liveness probe to a downstream dependency healthcheck (like testing database ping). If the database goes down temporarily, the liveness probe will fail, causing Kubernetes to restart the healthy API pod repeatedly. **Liveness probes should only check local container health (e.g. is the process alive?). Readiness probes should check downstream dependencies.**
* **Aggressive Probing Intervals**: Setting `periodSeconds` to very low values (e.g. 1 second) which causes high CPU usage from continuous polling and can overload the database or backend.

#### 5. Production DevOps Execution
In production team workflows:
* DevOps teams map probes to dedicated health endpoints (e.g. `/healthz/live` and `/healthz/ready`) built using standard libraries (such as ASP.NET Core Health Checks). The readiness endpoint tests the database connection, while the liveness endpoint simply checks if the server process is responsive.










