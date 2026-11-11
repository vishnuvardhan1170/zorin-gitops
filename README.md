# zorin-gitops

GitOps control plane for the zorin app. Contains the **Helm chart** and **ArgoCD Application** manifests that drive declarative deployments to GKE.

## How It Fits

```
zorin-app CI pushes image to Artifact Registry
        │
        ▼
deploy.yaml bumps image.tag in helm/values.yaml  ← THIS REPO
        │
        ▼
ArgoCD detects drift → syncs → Argo Rollouts canary deploy to GKE
```

No `kubectl apply`, no `helm upgrade` — all changes flow through git commits.

## Environments

| Env | Namespace | Rollouts | Strategy | Notes |
|-----|-----------|----------|----------|-------|
| dev | `zorin-dev` | disabled | RollingUpdate (plain Deployment) | Single replica, low resources |
| prod | `zorin` | enabled | Canary (10→30→60→100%, 5m pauses) | 3-node pool, higher limits |

## Helm Chart Structure

```
helm/
├── Chart.yaml
├── values.yaml              # Base (shared defaults)
├── values-dev.yaml          # Dev overrides
├── values-prod.yaml         # Prod overrides
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml      
    ├── service.yaml         
    ├── rollout/canary.yaml  #  → stable + canary Services + Rollout CR
    ├── configmap.yaml       
    ├── mongo-deployment.yaml # Stateful MongoDB
    ├── mongo-service.yaml   
    ├── secret-mongo.yaml    
    └── serviceaccount.yaml
```

## ArgoCD Applications

| File | App Name | Source | Destination |
|------|----------|--------|-------------|
| `argocd/app-dev.yaml` | `zorin-dev` | `helm/` + `values-dev.yaml` | ns `zorin-dev` |
| `argocd/app-prod.yaml` | `zorin-prod` | `helm/` + `values-prod.yaml` | ns `zorin` |

Both use:
- `automated.sync` with `prune: true`, `selfHeal: true`
- `CreateNamespace=true`
- Prod adds `ignoreDifferences` on `/spec/replicas` (Argo Rollouts manages replica count, not ArgoCD)

## Key Design Decisions

- **Two value files per env** — `values.yaml` holds shared defaults; env files override only what differs. ArgoCD loads them in order (`values.yaml` → `values-{env}.yaml`).
- **Rollouts conditional** — `rollouts.enabled` flips between a plain `Deployment` (dev) and an `argoproj.io/v1alpha1 Rollout` (prod). No Argo Rollouts CRD dependency in dev.
- **Mongo in-cluster** — StatefulSet with `ReadWriteOnce` PVC. Auth is scaffolded but disabled by default.
- **`ignoreDifferences` on prod** — prevents ArgoCD from fighting Argo Rollouts over `spec.replicas` during canary weight shifts.
- **`revisionHistoryLimit`** — 5 (dev), 10 (prod) for ArgoCD to track.

## Prerequisites

- ArgoCD installed on the GKE cluster (provisioned by `zorin-terraform`)
- Argo Rollouts controller installed (for prod canary)
- `helm` CLI available in ArgoCD's `repo-server` (or use `source.helm.valueFiles`)

## Deploying a New Image

The `deploy.yaml` workflow in `zorin-app` does this automatically:

```bash
# What CI does (you don't run this manually):
yq -i '.image.tag = "<sha>"' helm/values.yaml
git commit -m "chore: update zorin-app to <sha>"
git push
```

ArgoCD picks up the commit within its sync interval (default 3m) and triggers the rollout.

## Project Structure

```
├── README.md
├── argocd/
│   ├── app-dev.yaml         # ArgoCD Application for dev
│   └── app-prod.yaml        # ArgoCD Application for prod
└── helm/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-prod.yaml
    └── templates/
        ├── _helpers.tpl
        ├── configmap.yaml
        ├── deployment.yaml
        ├── mongo-deployment.yaml
        ├── mongo-service.yaml
        ├── secret-mongo.yaml
        ├── service.yaml
        ├── serviceaccount.yaml
        └── rollout/
            └── canary.yaml
```
