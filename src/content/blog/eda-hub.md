---
title: "EDA Hub: Exploratory Data Analysis Playground"
description: "A Jupyter-based collection of machine learning and data analysis projects covering image captioning, handwriting analysis, and business analytics."
date: 2026-05-20
tags: ["ai", "python"]
---

EDA Hub is a collection of Jupyter notebooks for exploratory data analysis, machine learning, and deep learning experiments. Each project lives in its own notebook with shared utilities across the repository.

## Projects

The image caption generator uses transfer learning with ResNet152 on the COCO dataset to generate natural language descriptions of images. It demonstrates how pre-trained CNNs can be combined with recurrent networks for sequence generation.

DARWIN is a handwriting analysis pipeline for Alzheimer's detection. It compares PCA with Logistic Regression against SVM classifiers to distinguish between healthy and affected handwriting samples using the DARWIN dataset.

The collection also includes business analytics on Adventure Works 2022 data, GPU versus CPU performance analysis, NASA facilities dataset exploration, and world cities statistics.

## Running it

```bash
make requirements
cd $HOME/workspace/eda-hub && python3 -m jupyter notebook
```

Each notebook is self-contained with detailed markdown sections explaining the methodology and results.

The source is available at [github.com/rflorenc/eda-hub](https://github.com/rflorenc/eda-hub).
