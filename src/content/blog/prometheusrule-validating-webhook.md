---
title: "PrometheusRule Validating Webhook"
description: "A Kubernetes admission webhook that enforces required labels on PrometheusRule custom resources in labeled namespaces."
date: 2026-04-10
tags: ["kubernetes", "go", "operators"]
---

When teams create PrometheusRule objects across a cluster, it is easy for rules to drift from organizational standards. Missing labels, incomplete group definitions, or inconsistent naming make it harder to trace alerts back to their owners.

This validating webhook intercepts PrometheusRule creation and update requests, checking that required fields and labels are present before the object is admitted to the cluster.

## How it works

The webhook uses namespace-scoped validation. Only namespaces carrying the label `app.kubernetes.io/created-by: webhook-managed.project.example.com` are subject to enforcement. Rules created in unlabeled namespaces pass through without checks.

When a PrometheusRule fails validation, the webhook returns a detailed error showing exactly which fields are missing from which rule groups.

## Deployment

The webhook deploys via Helm with full RBAC configuration. Certificate management is handled through cert-manager.

```bash
make webhook-linux
./helm-wrapper.sh -u
```

Tests run against a local Kubernetes API using envtest, so no full cluster is needed during development.

The source is available at [github.com/rflorenc/prometheusrule-validating-webhook](https://github.com/rflorenc/prometheusrule-validating-webhook).
