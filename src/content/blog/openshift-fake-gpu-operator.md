---
title: "OpenShift Fake GPU Operator"
description: "A Kubernetes operator that simulates NVIDIA GPU resources on OpenShift and Kubernetes clusters, enabling GPU workload development and testing without physical hardware."
date: 2026-06-25
tags: ["kubernetes", "go", "operators", "openshift"]
---

Testing GPU workloads on Kubernetes typically requires expensive NVIDIA hardware. The OpenShift Fake GPU Operator removes that dependency by simulating GPU resources at the cluster level, allowing you to develop, test, and validate GPU-dependent applications on any node.

## How it works

The operator manages a `FakeGPUConfig` custom resource that declares which GPU profile to simulate and how many GPUs per node. It supports seven built-in profiles covering NVIDIA architectures from Turing to Blackwell: A100, H100, H200, B200, GB200, L40S, and T4. Custom profiles are also supported for user-defined GPU specifications.

```yaml
apiVersion: gpu.openshift.io/v1alpha1
kind: FakeGPUConfig
metadata:
  name: fake-gpu
spec:
  gpuProfile: h100
  gpuCount: 4
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/worker: ""
```

When this resource is created, the operator deploys a set of components that make the cluster behave as if real GPUs are present.

## Components

The operator manages six core components, each deployed as a DaemonSet or Deployment:

**Device Plugin** registers `nvidia.com/gpu` as an extended resource with the kubelet via the standard Kubernetes device plugin interface. Pods requesting `nvidia.com/gpu` in their resource limits get scheduled to nodes where the fake plugin runs.

**Status Updater** patches node objects to reflect GPU capacity and maintains topology ConfigMaps with per-node GPU metadata including allocation status.

**Metrics Exporter** simulates NVIDIA DCGM by exposing Prometheus metrics on port 9400. Monitoring dashboards and alerts that depend on GPU metrics work without modification.

**Topology Server** provides an HTTP API serving GPU topology data, including GPU IDs, memory, product names, and partition information.

**MIG Faker** simulates Multi-Instance GPU partitioning when MIG is enabled. It supports both mixed and single strategies, registering `nvidia.com/mig-*` resources for each partition type. The A100, H100, H200, B200, and GB200 profiles include predefined MIG families.

**DRA Plugin** provides Dynamic Resource Allocation support for clusters running Kubernetes 1.33+, going beyond traditional device plugins.

## Node selection

Nodes can be selected automatically or manually. With a `nodeSelector` in the spec, the operator finds matching nodes and applies the required labels. Without it, you label nodes manually with `run.ai/simulated-gpu-node-pool=<name>`. The operator watches node resources and re-triggers reconciliation when the matching set changes.

## OpenShift and Kubernetes

The operator detects OpenShift automatically by checking for the SecurityContextConstraints API. On OpenShift, it creates the necessary SCC bindings so GPU components can run privileged. On plain Kubernetes, it skips SCC setup entirely. It also detects and prevents conflicts with existing Helm-based installations of the upstream fake-gpu-operator.

## Cleanup

Deletion uses the finalizer pattern to ensure all managed resources are removed: DaemonSets, Deployments, Services, ConfigMaps, RBAC, RuntimeClass, and node labels. Nothing is left behind when the `FakeGPUConfig` is deleted.

## Installation

```bash
kubectl apply -f https://raw.githubusercontent.com/rflorenc/openshift-fake-gpu-operator/main/dist/install.yaml
```

The source is available at [github.com/rflorenc/openshift-fake-gpu-operator](https://github.com/rflorenc/openshift-fake-gpu-operator).
