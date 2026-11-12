# GradeCalc: CI/CD pipeline on Azure

A Spring Boot grade calculator, built, tested, containerised and deployed to Azure Kubernetes Service by GitHub Actions on every push to `main`.

```
git push -> GitHub Actions
              |- Secret scan (gitleaks) ---+
              |- Build + test (Maven) -----+-> Docker build -> push to ACR -> Ansible deploy to AKS -> verify
```

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/`, `pom.xml` | Java 17 / Spring Boot application and unit tests |
| `Dockerfile`, `.dockerignore` | Runtime image built from the tested jar |
| `.github/workflows/ci-cd.yml` | The pipeline |
| `.gitleaks.toml` | Secret scanning configuration |
| `k8s/` | Namespace, Deployment and Service manifests |
| `ansible/` | Playbook and inventory that deploy the manifests |
| `infra/` | Scripts that create and delete the Azure resources |

## Pipeline

| Job | Runs on | What it does |
| --- | --- | --- |
| Secret scan | push, PR | gitleaks scans the full git history and fails on any finding |
| Build and test | push, PR | `mvn package`, then `mvn test`; uploads the jar and test reports |
| Build and push image | push to `main` | Builds the image from the tested jar, tags it with the commit SHA and `latest`, pushes to ACR |
| Deploy and verify | push to `main` | Ansible applies the manifests and waits for the rollout; the job then fails unless `/api/info` on the public IP reports this commit |

GitHub signs in to Azure with OpenID Connect, so no Azure password or key is stored in the repository.

## Run locally

```bash
mvn verify
java -jar target/app.jar     # http://localhost:8080
```

With Docker:

```bash
mvn package
docker build -t gradecalc .
docker run -p 8080:8080 gradecalc
```

## Set up Azure

Requires the Azure CLI and GitHub CLI, both signed in. The GitHub repository must already exist.

```bash
GITHUB_REPO=<owner>/<repo> ./infra/provision.sh
```

This creates a resource group, an Azure Container Registry, a one-node AKS cluster and an identity for GitHub Actions, then stores the connection settings in the repository. The optional variables `LOCATION`, `NODE_SIZE` and `ACR_NAME` override the defaults.

## Demonstrate a change

1. Edit `app.message` in `src/main/resources/application.properties`.
2. Commit and push to `main`.
3. Watch the run in the Actions tab.
4. Refresh the application: the new message and commit appear on the page.

## Rollout history and rollback

Each pipeline deploy records its commit as the revision's change cause.

```bash
kubectl -n gradecalc rollout history deployment/gradecalc
kubectl -n gradecalc rollout history deployment/gradecalc --revision=2
kubectl -n gradecalc rollout undo deployment/gradecalc --to-revision=1
```

Only changes to the pod template create a revision, so scaling does not. A rollback reuses the old ReplicaSet under a new revision number. After a manual edit, set the change cause yourself with `kubectl annotate`, or the new revision repeats the previous one.

## Clean up

The cluster bills for as long as it exists. Delete everything when you finish:

```bash
./infra/destroy.sh
```
