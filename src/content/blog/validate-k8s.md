---
title: "Kubernetes NetworkPolicy Gatekeeper"
description: "A validating and mutating webhook for enforcing NetworkPolicy compliance with ACM policy integration."
date: 2026-03-15
tags: ["kubernetes", "go", "security"]
---

NetworkPolicy objects are the primary mechanism for controlling pod-to-pod traffic in Kubernetes, but there is no built-in way to enforce that every namespace has one or that policies meet organizational standards.

This project implements both mutating and validating admission webhooks for NetworkPolicy resources. It integrates with Advanced Cluster Management to enforce compliance policies across managed clusters.

## What it enforces

The webhooks use label-based namespace selection to determine which namespaces are subject to policy enforcement. The validating webhook rejects NetworkPolicy objects that do not meet the required structure. The mutating webhook can inject defaults into policies that are missing required fields.

The repository includes example ACM policies with NIST compliance annotations for Open Cluster Management, making it straightforward to roll out network security baselines across a fleet of clusters.

## Running it

```bash
make build
./helm-wrapper.sh -u
make test
```

The test suite uses Ginkgo and Gomega with mock interfaces for the Kubernetes API.

The source is available at [github.com/rflorenc/validate-k8s](https://github.com/rflorenc/validate-k8s).
