---
title: "Harness Engineering for AI Agents"
description: "The emerging discipline of designing systems that make AI coding agents reliable and productive — context management, architectural constraints, and feedback loops."
date: 2026-06-26
tags: ["ai"]
---

The model is not the hard part anymore. What separates a useful AI coding agent from one that burns tokens and produces broken code is the harness — the infrastructure surrounding the model that constrains what it can do, informs it about what to do, verifies it did it correctly, and corrects it when it goes wrong.

The analogy comes from horse tack: the model is the horse, powerful but directionless alone. The harness is the reins, saddle, and bit. The engineer is the rider providing direction, not doing the running.

## Evidence it works

LangChain's coding agent jumped from 52.8% to 66.5% on Terminal Bench 2.0 by changing only the harness while keeping the same model. They added self-verification loops, directory structure mapping at startup, loop detection for repeated edits, and a reasoning sandwich pattern that uses high reasoning for planning and verification but medium for implementation.

OpenAI's Codex team reportedly built a production application exceeding one million lines of code over five months with no manually written lines. Engineers worked purely as harness designers.

## The three pillars

**Context engineering** ensures agents have the right information at the right time. This means repository-local documentation like architecture specs, API contracts, and style guides. It means `AGENTS.md` or `CLAUDE.md` files encoding project-specific rules. From the agent's perspective, anything not accessible in-context does not exist. The repository must be the single source of truth.

**Architectural constraints** mechanically enforce what good code looks like rather than asking agents to write good code. Dependency layering, deterministic linters with custom rules, structural tests, and pre-commit hooks all reduce the solution space. Paradoxically, constraining the space makes agents more productive — when they can generate anything, they waste tokens exploring dead ends.

**Entropy management** addresses the drift that accumulates over time in AI-generated codebases. Documentation goes stale, naming conventions diverge, dead code piles up. Periodic cleanup agents scan for deviations, update quality grades, and open targeted refactoring PRs. Think of it as garbage collection for code quality.

## The session protocol

Every agent session should follow the same lifecycle: orient by reading progress notes and recent git history, run the init script, verify the baseline works before touching anything, select one task, implement it, test it through actual UI or API interaction, update state, and exit clean.

One task per session prevents context exhaustion and keeps sessions recoverable. Verify before building catches compounding bugs across sessions, which is one of the most common failure modes.

## Feedback loops as backpressure

Type checkers, linters, test suites, and security scanners provide automated backpressure. The critical constraint is that the feedback wheel must turn fast. Slow verification reduces iteration count.

Browser automation deserves special attention. Agents will mark features complete without actually testing them unless forced to interact with the running application. Tools like Puppeteer or Playwright should navigate, click, fill forms, and take screenshots as part of the verification step.

## Separate generation from evaluation

Agents consistently rate their own work too generously. Having a separate evaluator agent with concrete grading criteria creates an honest feedback loop. Define specific criteria with clear definitions of what good looks like, few-shot examples for calibration, and hard thresholds that trigger a failing grade. Weight the criteria toward model weaknesses like design originality and feature completeness rather than strengths like basic functionality.

## The evolving role of the engineer

The shift is from writing code to designing environments where AI writes code, from debugging code to debugging agent behavior, from writing tests to designing test strategies, from maintaining docs to building documentation as machine-readable infrastructure. This requires deeper architectural thinking since you are designing systems that must work without constant human intervention.

Every component in a harness encodes an assumption about what the model cannot do on its own. When a new model arrives, strip scaffolding that is no longer load-bearing, add new components for newly possible capabilities, and test by removing one component at a time.

References: [Anthropic — Harness design for long-running agents](https://docs.anthropic.com/en/docs/agents-and-tools/), [OpenAI — Harness engineering with Codex](https://openai.com/index/codex/), [celesteanders — Harness engineering best practices](https://gist.github.com/celesteanders/21edad2367c8ede2ff092bd87e56a26f), [nxcode — Complete guide to harness engineering](https://www.nxcode.io/resources/news/harness-engineering-complete-guide-ai-agent-codex-2026).
