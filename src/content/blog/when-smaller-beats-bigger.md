---
title: "Why a 2B Model Beats an 8B Model: Evaluating LLMs Beyond Accuracy"
description: "Accuracy alone does not tell you if a model is useful in production. A composite scoring framework reveals that architectural design matters more than parameter count."
date: 2026-06-28
tags: ["ai", "python"]
---

We obsess over model size. A 70-billion-parameter model must be better than a 7-billion-parameter model, which must be better than a 2-billion-parameter model. More parameters, more knowledge, better results.

In our research evaluating ten small language models across four datasets, the top-performing model had 2 billion parameters. It outperformed every 7B and 8B model we tested. Not by a small margin. By a wide one.

The reason has nothing to do with some trick or special dataset. It has everything to do with how we define "performance" and what we actually need from a model in production.

## The datasets

We evaluated across four datasets from different domains, each presenting a distinct challenge.

The first two come from [Loghub](https://github.com/logpai/loghub), a widely used collection of system log datasets maintained by the Logpai team. HDFS logs were originally collected from a 203-node Hadoop cluster at UC Berkeley by Xu et al. for their 2009 SOSP paper on mining console logs. Each sample represents a block operation trace labeled as normal or abnormal. BGL logs come from a BlueGene/L supercomputer at Lawrence Livermore National Labs, containing 4.7 million messages from a system with 131,072 processors. The logs include alert and non-alert messages, though the dataset suffers from extreme class imbalance with roughly 99.7% normal samples.

[UNSW-NB15](https://research.unsw.edu.au/projects/unsw-nb15-dataset) is a network intrusion detection dataset created by Nour Moustafa and Jill Slay at the Australian Centre for Cyber Security in 2015. The traffic was generated using the IXIA PerfectStorm tool in their Cyber Range Lab, producing 2.5 million records across 49 network flow features with nine attack categories including Fuzzers, Backdoors, DoS, Exploits, and Reconnaissance. This dataset proved to be the most challenging for all models due to the complexity and diversity of the attack patterns.

[AssureMOSS](https://figshare.com/articles/dataset/AssureMOSS_Kubernetes_Run-time_Monitoring_Dataset/20463687) is a Kubernetes runtime monitoring dataset created by Clinton Cao and Agathe Blaise at TU Delft, funded under the EU H2020 program. It contains NetFlow data collected from a Kubernetes cluster running microservice applications, with labeled benign and malicious traffic. All models achieved near-perfect accuracy on it, suggesting that Kubernetes network anomalies produce highly distinguishable signatures.

## Accuracy is necessary but not sufficient

Every model we tested achieved high accuracy, with F1 scores ranging from 0.88 to 0.999. But consider two models that both achieve 99% accuracy. The first always gives you a clear answer. The second says "I'm not sure" half the time. On the samples where it commits, it is extremely accurate, hence the high score. But in a production system, it forces you to build a fallback for every other input.

This distinction does not show up in traditional metrics. We needed a new way to measure it.

## A composite score for production usefulness

We developed a scoring framework with three components.

**F1 Score** measures traditional classification accuracy. A model that gives decisive wrong answers is worse than useless, so accuracy accounts for half the composite weight.

**Decisiveness** measures how often a model commits to an actionable output versus deferring with uncertainty. A model with 100% decisiveness always gives you a definitive answer. A model with 50% decisiveness punts on half its inputs.

**Confidence** measures, among the decisive cases, how often the verification step agrees with the initial prediction rather than overriding it. High confidence means the model's first instinct is usually right. Low confidence means the verifier frequently overrides, suggesting internal inconsistency.

```
Composite = 50% × F1 + 30% × Decisiveness + 20% × Confidence
```

## The scoreboard

IBM's Granite-3.2-2B achieved a composite score of 96.3% with near-perfect F1 of 99.2%, complete decisiveness of 100%, and the highest confidence at 83.3%.

DeepSeek-R1-Qwen-7B came second at 87.9%. Its F1 and decisiveness matched Granite's, but its confidence was lower at 41.7% because its verifier rejected the initial prediction more often.

DeepSeek-R1-Llama-8B, four times Granite's size, scored only 73.9%. Despite having the highest raw F1 at 99.5%, it was only decisive 50% of the time.

## Three personality types

Across all ten models, we observed three distinct behavioral patterns. Each one traces back to how the model was trained.

The first type is the **decisive confirmer**. Granite-3.2-2B and Granite-3.2-8B both exhibit this pattern, with high CONFIRM rates and zero uncertainty. Granite was trained by IBM with a toggleable reasoning mode activated by a `thinking=true` parameter. The model was explicitly prepared for structured reasoning tasks. When our pipeline prompts it to "critically review this analysis," it knows how to evaluate reasoning because that capability was baked into its training. These are the most production-friendly models.

The second type is the **critical rejector**. DeepSeek-R1-Qwen-7B is the clearest example, with a 100% REJECT rate on some datasets. These models were distilled from DeepSeek-R1, a 671-billion-parameter model, using reinforcement learning followed by supervised fine-tuning. Their reasoning style is adversarial by nature. When asked to verify a prediction, they tend toward rejection, not because the predictions are wrong, but because the model's training disposition favors critical challenge over confirmation. The final answer is still accurate because the rejection comes with a corrected prediction, but the path is adversarial rather than confirmatory.

The third type is the **conservative hedger**. Llama-3.1-8B and Llama-3.2-3B show uncertainty rates of 83% to 100% on challenging datasets. These models were trained with reinforcement learning from human feedback for general-purpose alignment, not for structured reasoning or self-verification tasks. When asked to render a verification verdict, they consistently chose UNCERTAIN. They are capable classifiers but reluctant verifiers. Every uncertain verdict pushes the decision to a human, which defeats the purpose of automated analysis.

## What a fine-tuned verifier could change

Every model in our evaluation was a general-purpose model. None were specifically fine-tuned for log anomaly detection as a task. Whether any of them encountered log data during pre-training is a different question, and the answer depends on which model you ask about. IBM Granite and NVIDIA OpenReasoning-Nemotron have fully documented training datasets with permissive licensing. HuggingFace SmolLM2 also discloses its pre-training and fine-tuning data. But DeepSeek and Meta Llama do not disclose their training corpora in any meaningful detail, and Mistral and NVIDIA Hymba fall somewhere in between with partial descriptions. For the undisclosed models, we simply cannot rule out that system logs, network traffic data, or similar operational text was part of their training. What we can say is that none of them were trained with a log anomaly classification objective.

The expert panel in stage one actually benefits from being general-purpose. You want broad, varied perspectives there. But the verifier is a different story. Its job is to render a definitive judgment on whether the reasoning holds up. When Llama-3.1-8B returns UNCERTAIN on 100% of UNSW-NB15 samples, it is not confused about the reasoning quality. It lacks the domain knowledge to commit.

A verifier fine-tuned on thousands of labeled log anomalies would have that knowledge. It would know that a specific combination of packet sizes and port numbers is a well-documented attack signature, not an ambiguous edge case. This creates an asymmetric architecture: general-purpose models generating diverse expert analyses in stage one, and a specialized model rendering authoritative verdicts in stage two. We have not tested this yet, but the behavioral data strongly suggests it would collapse the uncertainty rates that currently separate the best models from the rest.

The pseudocode algorithms for the multi-perspective reasoning and verifier feedback pipeline are described in the [previous post](/blog/three-experts-one-model/).

The SCARLOG framework and all evaluation code are available at [github.com/rflorenc/SCARLOG](https://github.com/rflorenc/SCARLOG).
