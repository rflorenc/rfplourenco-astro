---
title: "Getting Started with Google ADK in Go"
description: "A quick walkthrough of building an AI agent in Go using Google's Agent Development Kit with Gemini and tool support."
date: 2026-06-26
tags: ["ai", "go"]
---

Google released the [Agent Development Kit](https://adk.dev) for building AI agents across multiple languages. The Go SDK makes it straightforward to create agents powered by Gemini with built-in tool support and both CLI and web interfaces.

## Setup

You need Go 1.24+ and a Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey).

```bash
mkdir -p my_agent && cd my_agent
go mod init my-agent/main
```

## Building an agent

The core flow is: create a model, create an agent with tools, wrap it in a launcher, and execute. Here is a minimal agent that uses Google Search to answer questions:

```go
package main

import (
    "context"
    "log"
    "os"

    "google.golang.org/adk/agent"
    "google.golang.org/adk/agent/llmagent"
    "google.golang.org/adk/cmd/launcher"
    "google.golang.org/adk/cmd/launcher/full"
    "google.golang.org/adk/model/gemini"
    "google.golang.org/adk/tool"
    "google.golang.org/adk/tool/geminitool"
    "google.golang.org/genai"
)

func main() {
    ctx := context.Background()

    model, err := gemini.NewModel(ctx, "gemini-flash-latest", &genai.ClientConfig{
        APIKey: os.Getenv("GOOGLE_API_KEY"),
    })
    if err != nil {
        log.Fatalf("Failed to create model: %v", err)
    }

    timeAgent, err := llmagent.New(llmagent.Config{
        Name:        "hello_time_agent",
        Model:       model,
        Description: "Tells the current time in a specified city.",
        Instruction: "You are a helpful assistant that tells the current time in a city.",
        Tools: []tool.Tool{
            geminitool.GoogleSearch{},
        },
    })
    if err != nil {
        log.Fatalf("Failed to create agent: %v", err)
    }

    config := &launcher.Config{
        AgentLoader: agent.NewSingleLoader(timeAgent),
    }

    l := full.NewLauncher()
    if err = l.Execute(ctx, config, os.Args[1:]); err != nil {
        log.Fatalf("Run failed: %v\n\n%s", err, l.CommandLineSyntax())
    }
}
```

## Running it

Set your API key and run:

```bash
export GOOGLE_API_KEY="your-key-here"
go run agent.go
```

This starts an interactive CLI session. For a web interface with a chat UI on `localhost:8080`:

```bash
go run agent.go web api webui
```

## Key concepts

The SDK is built around five pieces: **Models** are the underlying LLM created via `gemini.NewModel`. **Tools** are capabilities like Google Search passed as a slice in the agent config. **Agents** combine a model, tools, and instructions via `llmagent.New`. The **Launcher** handles execution in CLI or web mode. The **AgentLoader** wires agents into the launcher config.

The web interface is for development and debugging only. For production, you would integrate the agent into your own server.

Full documentation at [adk.dev/get-started/go](https://adk.dev/get-started/go/).
