# Full-Stack Todo Application

A modern, containerized, production-ready Full-Stack Todo Application built using Clean Architecture, SOLID principles, and design aesthetics.

## Tech Stack
*   **Backend**: .NET 9.0 Web API, Entity Framework Core 9, MySQL 8.0, BCrypt.Net (Password Hashing), AutoMapper (DTO Mapping), FluentValidation (Request Validation), Global Exception Middleware, Swagger UI.
*   **Frontend**: Angular 21 Standalone Components, Angular Material, Reactive Forms, Auth Guard, JWT Interceptor, Responsive Glassmorphic Dark Styling.
*   **Containerization**: Docker (Separate containers connected via a custom bridge network).

---

## Project Structure
```text
todo/
├── README.md                   # Project documentation
│
├── TodoApi/                    # Backend Project
│   ├── Controllers/            # API Endpoints (Auth, Todos)
│   ├── Data/                   # DbContext & Entity Configurations
│   ├── DTOs/                   # Request & Response Data Transfer Objects
│   ├── Mapping/                # AutoMapper Profile mapping configurations
│   ├── Middleware/             # Global Exception Middleware
│   ├── Models/                 # Database Domain Entities (User, Todo)
│   ├── Repositories/           # Data access layers (Repository pattern)
│   ├── Services/               # Business logic layers (Service pattern)
│   ├── Validators/             # FluentValidation rules for DTOs
│   ├── Migrations/             # EF Core Database Migration files
│   ├── Dockerfile              # Multi-stage Docker build for backend
│   └── .env                    # Local environment config
│
└── todo-ui/                    # Frontend Project
    ├── src/
    │   ├── app/
    │   │   ├── components/     # Pages (Login, Register, Dashboard, Dialog)
    │   │   ├── guards/         # Route security (Auth Guard)
    │   │   ├── interceptors/   # Auth header injector (JWT Interceptor)
    │   │   ├── models/         # TypeScript interface schemas
    │   │   ├── services/       # State management and API services (Signals)
    │   │   ├── app.routes.ts   # Route definitions
    │   │   └── app.config.ts   # Dependency injection providers
    │   └── styles.scss         # Global styles (Glassmorphism dark theme)
    ├── nginx.conf              # Nginx configuration for hosting SPA
    └── Dockerfile              # Multi-stage Docker build for frontend
```

---

## Prerequisites
*   [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running on your system.
*   [Minikube](https://minikube.sigs.k8s.io/docs/start/) and [kubectl](https://kubernetes.io/docs/tasks/tools/) installed (for Kubernetes deployment).
*   [Helm 3](https://helm.sh/docs/intro/install/) installed (for Helm deployment).

---

## Getting Started

You can run the application using **Docker Compose** (recommended, quick & easy) or run the individual manual Docker CLI commands.

### Option A: Using Docker Compose (Recommended)

To build and run all services (frontend, backend, database) with a single command, run the following from the root directory:

```bash
docker compose up --build -d
```

This will automatically:
1. Spin up the MySQL database and wait until it is healthy and accepting connections.
2. Build the backend container and apply Entity Framework Core database migrations.
3. Build the frontend container (served via Nginx).
4. Run everything on a shared network.

To stop and remove all services run:
```bash
docker compose down
```

To also delete the database volume (reset the DB):
```bash
docker compose down -v
```

### Option B: Using Manual Docker CLI Commands

If you prefer to run and manage each container manually, follow these steps:

#### 1. Create a Docker Network
Create a custom bridge network so the containers can resolve each other by their container names via DNS:
```bash
docker network create todo-network
```

#### 2. Run the MySQL 8.0 Database Container
Start a MySQL 8 container attached to the network, setting root password and initial database name:
```bash
docker run -d --name todo-mysql-db --network todo-network -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root_password -e MYSQL_DATABASE=todo_db mysql:8.0
```

#### 3. Build & Run the Backend Container (.NET 9 Web API)
Compile and publish the backend code inside the .NET 9 SDK container:

*   **Build the Image**:
    ```bash
    docker build -t todo-backend ./TodoApi
    ```

*   **Run the Container**:
    Connects to the database container using host `todo-mysql-db`. We specify environment configurations via environment variables (`-e` flags) and map host port 5000 to container port 5000:
    ```bash
    docker run -d --name todo-web-api --network todo-network -p 5000:5000 -e DB_CONNECTION_STRING="Server=todo-mysql-db;Port=3306;Database=todo_db;User=root;Password=root_password;" -e JWT_SECRET=SuperSecretKeyForTodoAppAuthJWTToken2026 -e JWT_ISSUER=TodoApi -e JWT_AUDIENCE=TodoUi -e RUN_MIGRATIONS=true -e ENABLE_SWAGGER=true todo-backend
    ```

#### 4. Build & Run the Frontend Container (Angular UI + Nginx)
Compile Angular production assets and serve them using Nginx:

*   **Build the Image**:
    ```bash
    docker build -t todo-frontend ./todo-ui
    ```

*   **Run the Container**:
    Maps port 4200 on the host to port 80 in the container, joining the shared Docker network:
    ```bash
    docker run -d --name todo-angular-ui --network todo-network -p 4200:80 todo-frontend
    ```

---

### Minikube Setup (From Scratch)

Before running Option C or Option D, initialize your local Minikube cluster and build the container images directly inside its Docker registry:

1. **Start Minikube**:
   ```bash
   minikube start
   ```

2. **Enable the Ingress Addon**:
   ```bash
   minikube addons enable ingress
   ```

3. **Configure your shell's Docker daemon**:
   Configure your host's Docker CLI to communicate directly with the Docker daemon running inside Minikube:
   * **For Bash / Git Bash**:
     ```bash
     eval $(minikube docker-env)
     ```
   * **For PowerShell**:
     ```powershell
     & minikube docker-env | Invoke-Expression
     ```

4. **Build the Application Images**:
   Build the backend and frontend Docker images directly inside the Minikube Docker environment:
   ```bash
   docker build -t todo-backend:latest ./TodoApi
   docker build -t todo-frontend:latest ./todo-ui
   ```

---

### Option C: Using Kubernetes Manifests Only

Once your Minikube cluster and images are ready (see *Minikube Setup (From Scratch)* above), deploy the stack using raw Kubernetes manifests:

1. **Apply Manifests**:
   ```bash
   kubectl apply -f k8s/
   ```

2. **Verify Deployment**:
   ```bash
   kubectl get all -n todo-app
   ```
   Wait for all pods to show `STATUS: Running` and `READY: 1/1`.

3. **Access the App**:
   Since Ingress is enabled on Minikube, you can fetch the Minikube IP:
   ```bash
   minikube ip
   ```
   Add an entry in your local hosts file (`C:\Windows\System32\drivers\etc\hosts`) mapping `minikube ip` to your domain or map a port forwarding tunnel for direct localhost access:
   ```bash
   kubectl port-forward svc/ui-service 8081:80 -n todo-app
   ```
   Open your browser at [http://localhost:8081](http://localhost:8081).

4. **Stop and Clean Up**:
   ```bash
   kubectl delete -f k8s/
   ```

### Option D: Using Helm (Recommended for Kubernetes)

Once your Minikube cluster and images are ready (see *Minikube Setup (From Scratch)* above), deploy and manage the stack using the Helm chart:

1. **Deploy using the four values files**:
   ```bash
   helm install todo ./helm/todo-app -f ./helm/todo-app/values-common.yaml -f ./helm/todo-app/values-settings.yaml -f ./helm/todo-app/values-size.yaml -f ./helm/todo-app/values-secrets.yaml
   ```

3. **Verify Deployment**:
   ```bash
   kubectl get all -n todo-app
   ```

4. **Access the App**:
   Use port-forwarding to browse the UI:
   ```bash
   kubectl port-forward svc/ui-service 8081:80 -n todo-app
   ```
   Open your browser at [http://localhost:8081](http://localhost:8081).

5. **Uninstall Release**:
   ```bash
   helm uninstall todo
   ```

---

## Accessing the Application
Once the containers are running and database migrations are automatically applied on startup:

*   **Frontend Web App**: [http://localhost:4200](http://localhost:4200) (requests to `/api` are automatically proxied to `todo-web-api` inside Docker)
*   **Backend API Swagger UI**: [http://localhost:5000/swagger/index.html](http://localhost:5000/swagger/index.html)
*   **MySQL Server Database**: `localhost:3306` (Credentials: Username `root`, Password `root_password`)

---

## Stopping & Cleaning Up Manual Containers
To stop and remove manual containers and network:
```bash
docker stop todo-angular-ui todo-web-api todo-mysql-db
docker rm todo-angular-ui todo-web-api todo-mysql-db
docker network rm todo-network
```

---

## Git Versioning Setup

To push the backend and frontend code bases to their respective GitHub repositories:

### Backend Repository
Initialize Git in the backend directory, connect it to the repository, stage, and commit:
```bash
# From the backend TodoApi directory
git init
git remote add origin https://github.com/NIVEDNRAJ/nest-todo-backend.git
git add .
git commit -m "Initial .NET 9 Todo Backend commit"
```

### Frontend Repository
Add the repository remote url in the frontend directory, stage, and commit:
```bash
# From the frontend todo-ui directory
git remote add origin https://github.com/NIVEDNRAJ/nest-todo-frontend.git
git add .
git commit -m "Initial Angular Todo Frontend commit"
```

---

## Architecture & Features

### Backend Highlights
1.  **Repository + Service Pattern**: Encapsulates DB logic (EF Core) in the Repository layer and business logic (mapping, security validation) in the Service layer, enabling loose coupling and testability.
2.  **JWT Authentication**: Secures endpoints under the `[Authorize]` attribute. Password hashing is secured using `BCrypt`.
3.  **Global Exception Middleware**: Intercepts unhandled errors, logs exceptions, and maps them to standard HTTP status codes (e.g. `401 Unauthorized`, `404 Not Found`, `400 Bad Request`) returned as camelCase JSON payloads.
4.  **Automatic Migrations**: On container startup, the backend checks environment configurations and automatically applies EF database migrations using:
    ```csharp
    dbContext.Database.Migrate();
    ```

### Frontend Highlights
1.  **Angular Signals**: Reactive state management is configured using Signals (e.g. `currentUser()`, `isAuthenticated()`, `todos()`), minimizing unnecessary template redraws and increasing rendering performance.
2.  **Functional Interceptors & Guards**: JWT token injection and dashboard route guards are built using functional patterns.
3.  **Visual Aesthetics**: Curated premium glassmorphic dark theme using smooth transitions, micro-animations, layout grids, Outfit typography, and custom components.
