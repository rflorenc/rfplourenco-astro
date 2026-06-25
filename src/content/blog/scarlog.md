---
title: "SCARLOG: Self-Consistent Anomaly Reasoning for Logs"
description: "A research framework for evaluating log anomaly detection using LLM reasoning, with multi-backend inference and system monitoring."
date: 2026-06-01
tags: ["ai", "python", "security"]
---

Log anomaly detection is a critical part of security and reliability engineering. SCARLOG is a research framework for evaluating how well large language models can reason about log data to identify anomalies.

## Architecture

The framework is built around a modular design with four core components: configuration, inference, evaluation, and monitoring. Configuration is driven by dataclasses for model, dataset, and system parameters. The inference layer supports multiple backends including local Transformers, vLLM for high-throughput serving, and is extensible for additional providers.

Evaluation covers standard anomaly detection metrics with support for clustering techniques like DBSCAN and HDBSCAN. The monitoring module tracks system resources during experiments, capturing CPU, GPU, and power consumption data for reproducibility.

## Supported models

The framework has been tested with Mistral and Mamba-1.5B-Instruct models. It supports quantization through BitsAndBytes and parameter-efficient fine-tuning via PEFT, making it feasible to run experiments on consumer hardware.

## Running benchmarks

```bash
make install-dev
pytest tests/ -m "not gpu and not slow"
./benchmarks/benchmark-test.sh
./benchmarks/benchmark-large.sh
```

The benchmark scripts come in three tiers: test for quick validation, small for iterative development, and large for full evaluation runs.

The source is available at [github.com/rflorenc/SCARLOG](https://github.com/rflorenc/SCARLOG).
