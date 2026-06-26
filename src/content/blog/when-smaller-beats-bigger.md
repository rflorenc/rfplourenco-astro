---
title: "Why a 2B Model Beats an 8B Model: Evaluating LLMs Beyond Accuracy"
description: "Accuracy alone does not tell you if a model is useful in production. A composite scoring framework reveals that architectural design matters more than parameter count."
date: 2026-06-28
tags: ["ai", "python"]
---

We obsess over model size. A 70-billion-parameter model must be better than a 7-billion-parameter model, which must be better than a 2-billion-parameter model. More parameters, more knowledge, better results.

In our research evaluating ten small language models across four datasets, the top-performing model had 2 billion parameters. It outperformed every 7B and 8B model we tested. Not by a small margin. By a wide one.

The reason has nothing to do with some trick or special dataset. It has everything to do with how we define "performance" and what we actually need from a model in production.

## Accuracy is necessary but not sufficient

Every model we tested achieved high accuracy. F1 scores ranged from 0.88 to 0.999 across different datasets. If accuracy were the only metric that mattered, you could pick almost any model from our lineup and call it a day.

But accuracy alone does not tell you whether a model is useful in a real system. Consider two models that both achieve 99% accuracy on the same task. The first model always gives you a clear, definitive answer. The second model gives you a clear answer half the time and says "I'm not sure" the other half. On the samples where it does commit, it is extremely accurate, hence the high overall score.

Which model would you rather deploy? The answer depends on your use case, but for most production systems, the model that always commits to an answer is more valuable. The one that hedges half the time forces you to build a fallback system, staff a human review queue, or simply accept that half your inputs produce no actionable output.

This distinction does not show up in traditional metrics like F1, precision, or recall. We needed a new way to measure it.

## A composite score for production usefulness

We developed a scoring framework with three components.

**F1 Score** measures traditional classification accuracy. This is the foundation. A model that gives decisive wrong answers is worse than useless, so accuracy still accounts for half the composite weight.

**Decisiveness** measures how often a model commits to an actionable output versus deferring with uncertainty. We calculate this as the percentage of cases where the model's self-verification step produces a CONFIRM or REJECT verdict rather than an UNCERTAIN one. A model with 100% decisiveness always gives you a definitive answer. A model with 50% decisiveness punts on half its inputs.

**Confidence** measures, among the cases where the model is decisive, how often its verification step agrees with the initial prediction rather than overriding it. High confidence means the model's first instinct is usually right and the verifier confirms it. Low confidence means the verifier frequently overrides the initial prediction, suggesting internal inconsistency in the model's reasoning.

The formula weights these three dimensions:

```
Composite = 50% × F1 + 30% × Decisiveness + 20% × Confidence
```

F1 gets the largest weight because nothing else matters if the model is wrong. Decisiveness gets the second largest because an indecisive model creates operational burden. Confidence gets the smallest because even a model that frequently self-corrects is useful, as long as it eventually arrives at the right answer.

## The scoreboard

When we ranked our ten models by this composite score, the results overturned the parameter-count hierarchy.

IBM's Granite-3.2-2B, with only 2 billion parameters, achieved a composite score of 96.3%. It posted near-perfect F1 of 99.2%, complete decisiveness of 100%, and the highest confidence at 83.3%. It never hedged, never said "I'm not sure," and its initial predictions were confirmed by the verifier five out of six times.

DeepSeek-R1-Qwen-7B, with 7 billion parameters, came second at 87.9%. Its F1 matched Granite's at 99.2%, and its decisiveness was also perfect at 100%. But its confidence was lower at 41.7% because its verifier rejected the initial prediction more often. The model is decisive and accurate, but it reaches the right answer through self-correction rather than getting it right the first time.

DeepSeek-R1-Llama-8B, with 8 billion parameters and four times Granite's size, scored only 73.9%. Despite having the highest raw F1 at 99.5%, it was only decisive 50% of the time. Half its verification decisions came back as UNCERTAIN. In a production system, this model would require human review for every other input.

## Why training methodology matters more than size

The reason Granite-2B outperforms models four times its size is not mysterious once you look at how these models were trained.

Granite was trained by IBM on their Blue Vela supercomputer using permissively licensed datasets and synthetic data. Critically, it includes a toggleable reasoning mode activated by a `thinking=true` parameter. This means the model was explicitly trained to engage in structured reasoning when asked to. When our verification pipeline prompts it to "critically review this analysis," Granite has been specifically prepared for that kind of task. It knows how to evaluate reasoning because that capability was baked into its training.

The DeepSeek-R1-Distill series takes a different approach. These models were distilled from DeepSeek-R1, a massive 671-billion-parameter Mixture-of-Experts model, using a two-stage process of reinforcement learning followed by supervised fine-tuning. They are excellent reasoners. But their reasoning style is adversarial by nature. When asked to verify a prediction, they tend toward rejection. DeepSeek-R1-Qwen-7B rejected 100% of initial predictions on the HDFS dataset, not because the predictions were wrong, but because the model's training disposition favors critical challenge over confirmation.

The Llama models tell yet another story. Llama-3.1-8B and Llama-3.2-3B were trained with reinforcement learning from human feedback for general-purpose alignment. They were not specifically trained for structured reasoning or self-verification tasks. When asked to render a verification verdict, they consistently chose UNCERTAIN, producing 0% CONFIRM and 0% REJECT across some datasets. They are capable classifiers but reluctant verifiers.

## Three personality types

Across all ten models, we observed three distinct behavioral patterns that transcend individual model families.

The first type is the decisive confirmer. These models commit to an answer and their verifier usually agrees with the initial prediction. Granite-3.2-2B and Granite-3.2-8B both exhibit this pattern, with high CONFIRM rates and zero uncertainty. They are the most production-friendly because they produce consistent, actionable outputs with minimal self-correction overhead.

The second type is the critical rejector. These models commit to an answer but their verifier frequently overrides the initial prediction. DeepSeek-R1-Qwen-7B is the clearest example, with a 100% REJECT rate on some datasets. The final answer is still accurate because the rejection comes with a corrected prediction. But the path to that answer is adversarial rather than confirmatory. These models are useful when you want maximum scrutiny, but they introduce more computational overhead because the verification step is doing real work rather than rubber-stamping.

The third type is the conservative hedger. These models avoid committing to any verdict at all. Llama-3.1-8B and Llama-3.2-3B show uncertainty rates of 83% to 100% on challenging datasets. They are not wrong per se, but they are not helpful either. Every uncertain verdict pushes the decision to a human, which defeats the purpose of automated analysis.

Understanding which type a model belongs to helps you predict how it will behave in your pipeline before you deploy it. If you need autonomous decision-making, choose a decisive confirmer. If you need maximum scrutiny and can afford the overhead, consider a critical rejector. Avoid conservative hedgers for any application where throughput matters.

## What this means for model selection

The standard approach to choosing a model is to look at leaderboard benchmarks, pick the highest scorer in your budget, and deploy it. Our results suggest this process is incomplete.

Two models with identical F1 scores can have wildly different production characteristics. One might always give you a clear answer while the other hedges constantly. One might confirm its own reasoning while the other challenges everything it produces. These behavioral differences do not show up on any standard benchmark.

Before deploying a model for a classification, verification, or decision-support task, run it through a verification pipeline and measure not just accuracy but decisiveness and confidence. The composite score gives you a single number that captures production usefulness rather than just theoretical correctness.

And do not assume that bigger is better. A well-trained 2-billion-parameter model that was explicitly designed for structured reasoning will outperform an 8-billion-parameter model that was trained for general-purpose conversation. The architecture and training methodology of the model determine its behavior in your pipeline far more than the number of parameters it contains.

## What a fine-tuned verifier could change

Every model in our evaluation was a general-purpose model. None were specifically fine-tuned for log anomaly detection as a task. Whether any of them encountered log data during pre-training is a different question, and the answer depends on which model you ask about. IBM Granite and NVIDIA OpenReasoning-Nemotron have fully documented training datasets with permissive licensing. HuggingFace SmolLM2 also discloses its pre-training and fine-tuning data. But DeepSeek and Meta Llama do not disclose their training corpora in any meaningful detail, and Mistral and NVIDIA Hymba fall somewhere in between with partial descriptions. For the undisclosed models, we simply cannot rule out that system logs, network traffic data, or similar operational text was part of their training. What we can say is that none of them were trained with a log anomaly classification objective. This distinction matters most at the verification stage, because the verifier is the single point that determines the final verdict.

The expert panel in stage one actually benefits from being general-purpose. You want broad, varied perspectives there. A network security expert prompt and a threat hunter prompt produce more interesting disagreements when the model behind them has wide-ranging knowledge rather than narrow specialization. Diversity in the first stage is a feature, not a limitation.

The verifier is a different story. Its job is not to explore possibilities. Its job is to render a definitive judgment on whether the reasoning holds up. That requires domain confidence. When Llama-3.1-8B returns UNCERTAIN on 100% of UNSW-NB15 samples, it is not confused about the reasoning quality. It lacks the domain knowledge to commit. It does not know what a genuine network intrusion pattern looks like versus a noisy false positive, so it hedges.

A verifier fine-tuned on thousands of labeled log anomalies would have that knowledge. It would know that a specific combination of packet sizes and port numbers is a well-documented attack signature, not an ambiguous edge case. It would know that certain HDFS block operation sequences always indicate corruption. That domain grounding would let it commit to CONFIRM or REJECT instead of defaulting to UNCERTAIN.

This creates an asymmetric architecture: general-purpose models generating diverse expert analyses in stage one, and a specialized model rendering authoritative verdicts in stage two. The first stage stays cheap and flexible. The second stage gets the fine-tuned precision that matters for production reliability. We have not tested this yet, but the behavioral data strongly suggests it would collapse the uncertainty rates that currently separate the best models from the rest.

The formal algorithms for the multi-perspective reasoning and verifier feedback pipeline are described in the [previous post](/blog/three-experts-one-model/).

The SCARLOG framework and all evaluation code are available at [github.com/rflorenc/SCARLOG](https://github.com/rflorenc/SCARLOG).
