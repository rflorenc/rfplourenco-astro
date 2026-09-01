---
title: "Red Hat Support MCP Server"
description: "An MCP server that connects Claude Code to the Red Hat knowledge base, support cases, and security advisories with token-efficient output."
date: 2026-08-31
tags: ["python", "ai"]
---

Red Hat support workflows involve jumping between the knowledge base, the case portal, and errata pages. The Red Hat Support MCP server brings all three into Claude Code as tools, so you can search KCS articles, check case status, and look up security advisories without leaving your terminal.

## How it works

The server exposes five tools over the Model Context Protocol: `kcs_search` for searching the knowledge base, `kcs_get` for fetching full article details, `case_list` and `case_show` for support cases, and `errata_get` for security advisories like RHSAs. Authentication uses an offline token exchanged against Red Hat SSO, with automatic refresh when the access token expires.

Product names can be long. The server maps short aliases like `ocp`, `rhel`, `odf`, and `ceph` to their full Red Hat product names, so you can type `ocp` instead of "Red Hat OpenShift Container Platform" when filtering searches.

## Output compression

Raw API responses from Hydra and the Cases API contain deeply nested JSON with HTML fragments, redundant metadata, and fields an LLM does not need. The server strips HTML to markdown, filters to relevant fields, and truncates where appropriate. This keeps responses informative without burning through the context window.

## Running it

```bash
export REDHAT_TOKEN="<your-offline-token>"
pip install -e .
rh-support-mcp
```

To register with Claude Code:

```bash
claude mcp add rh-support \
  -s user \
  -e REDHAT_TOKEN="$(cat ~/.rh-offline-token | tr -d '\n')" \
  -- rh-support-mcp
```

Once registered, you can ask things like "search KCS for ODF ceph full ratio", "list my open support cases", or "look up errata RHSA-2025:1234" directly in your session.

The source is available at [github.com/rflorenc/rh-support-mcp](https://github.com/rflorenc/rh-support-mcp).
