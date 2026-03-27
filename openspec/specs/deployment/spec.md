# Spec: Deployment

## Purpose

Define the CI/CD pipeline using GitHub Actions for automated building, testing, Docker image management, and deployment to Dokploy.

## Requirements

### Requirement: GitHub Actions CI Pipeline
The backend repository SHALL have a GitHub Actions workflow that builds, tests, and validates code on every push and pull request.

#### Scenario: CI runs on pull request
- **WHEN** a pull request is opened or updated targeting the main branch
- **THEN** the CI workflow SHALL run lint, type check, and Docker build validation
- **AND** the workflow status SHALL be reported on the pull request

#### Scenario: CI builds Docker image on main branch
- **WHEN** code is pushed to the main branch
- **THEN** the CI workflow SHALL build a Docker image
- **AND** the image SHALL be pushed to GitHub Container Registry (GHCR)
- **AND** the image SHALL be tagged with the commit SHA and `latest`

#### Scenario: CI fails on lint errors
- **WHEN** the lint step detects errors
- **THEN** the workflow SHALL fail
- **AND** the pull request SHALL be blocked from merging (if branch protection enabled)

### Requirement: GitHub Actions CD Pipeline
The backend repository SHALL have a GitHub Actions workflow that triggers deployment to Dokploy after successful builds on the main branch.

#### Scenario: Deployment triggered after successful build
- **WHEN** the CI workflow completes successfully on the main branch
- **THEN** the CD workflow SHALL trigger a deployment to Dokploy via webhook
- **AND** the workflow SHALL wait for the deployment to complete

#### Scenario: Health check verified after deployment
- **WHEN** the Dokploy deployment completes
- **THEN** the CD workflow SHALL verify the health check endpoint returns HTTP 200
- **AND** the deployment status SHALL be recorded on the commit

#### Scenario: Deployment fails health check
- **WHEN** the health check fails after deployment
- **THEN** the workflow SHALL report failure
- **AND** the commit SHALL be marked with a failed deployment status

### Requirement: Docker Image Optimization
The Dockerfile SHALL be optimized for CI/CD builds and production deployment.

#### Scenario: Production image excludes dev dependencies
- **WHEN** the Docker image is built
- **THEN** the production stage SHALL NOT contain development dependencies
- **AND** the image size SHALL be minimized

#### Scenario: Image supports health checks
- **WHEN** the container starts
- **THEN** the HEALTHCHECK directive SHALL verify `/api/health` returns successfully
- **AND** unhealthy containers SHALL be marked for replacement

### Requirement: Image Registry Integration
Docker images SHALL be stored in GitHub Container Registry and pulled by Dokploy.

#### Scenario: Image pushed to GHCR
- **WHEN** a successful build occurs on main branch
- **THEN** the image SHALL be pushed to `ghcr.io/<org>/infinite-stories-backend`
- **AND** the image SHALL be accessible to the Dokploy deployment

#### Scenario: Image versioning
- **WHEN** an image is pushed
- **THEN** it SHALL be tagged with the git commit SHA
- **AND** it SHALL be tagged with `latest` for the most recent main branch build
