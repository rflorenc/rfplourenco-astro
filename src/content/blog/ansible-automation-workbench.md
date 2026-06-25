---
title: "Ansible Automation Workbench"
description: "A web-based UI for managing AWX and Ansible Automation Platform environments, built with Go and React."
date: 2026-06-15
tags: ["kubernetes", "ansible", "go"]
---

Managing multiple AWX and Ansible Automation Platform 2.x environments gets tedious fast. The Ansible Automation Workbench is a single-binary tool that bundles a Go backend with an embedded React frontend to give you a unified interface for browsing, migrating, and exporting resources across your automation platforms.

## What it does

The workbench connects to AWX or AAP instances via their APIs and provides an object browser for exploring resources like job templates, inventories, credentials, and projects. It supports API-driven migration between environments with preview and conflict detection, so you can move assets without surprises.

There is also a populate tool for spinning up sample objects useful in testing, and a cleanup automation that removes non-critical objects when you need to reset an environment. All assets can be exported and downloaded as JSON for backup or version control.

## Running it

The project compiles into a single binary with the React frontend embedded via a multi-stage Docker build. You can run it locally or deploy it to Kubernetes or OpenShift using the included Helm chart.

```bash
make build
./autoworkbench --config config.yaml
```

For development, the frontend and backend run separately with hot reload.

The source is available at [github.com/rflorenc/ansible-automation-workbench](https://github.com/rflorenc/ansible-automation-workbench).
