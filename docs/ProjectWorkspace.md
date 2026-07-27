# AI Project Workspace

## Vision

Build an AI-first application for managing **complex personal projects**
rather than AI conversations.

Examples: - Home renovations - Buying a car - Starting a business -
Planning a holiday - Building software - Researching large purchases

The AI is an assistant operating on a **persistent project model**, not
a chat history.

------------------------------------------------------------------------

# Core Insight

Current AI products store conversations.

This product stores **knowledge**.

Conversations are temporary.

Decisions, research, tasks, and requirements become structured artifacts
that evolve over time.

------------------------------------------------------------------------

# Example Workflow

Goal

↓

Research

↓

Decisions

↓

Requirements

↓

Purchases

↓

Tasks

↓

Execution

The AI continuously helps the user progress through this lifecycle.

------------------------------------------------------------------------

# Primary Artifact Types (MVP)

-   Topics
-   Conversations
-   Decisions
-   Open Questions
-   Tasks

Future artifacts:

-   Requirements
-   Risks
-   Purchases
-   Measurements
-   Files
-   Photos
-   Notes

------------------------------------------------------------------------

# Example Project

Guest House

Topics

-   Electricity
-   Ethernet
-   Water
-   Drainage

Drainage

Research - Gravity drainage - Macerator - Pump station

Decision - Use a lifting station

Reason - Lowest maintenance - Lowest installation complexity

Open Questions - Required flow rate - Pump model

Tasks - Purchase pump - Dig trench - Connect sewer

------------------------------------------------------------------------

# Product Principles

## Conversation is an input

Chat is only used to gather information.

It is not the permanent representation.

## AI maintains project memory

The AI proposes updates after conversations.

Example:

Suggested updates

-   New decision
-   Two new tasks
-   One resolved question

The user reviews and accepts or rejects changes.

## Structured over unstructured

The application should always prefer structured knowledge over long chat
histories.

## Project-aware reasoning

The AI reasons using:

-   current decisions
-   project goals
-   related topics
-   dependencies

rather than entire conversation history.

------------------------------------------------------------------------

# Recommended Architecture

Project

├── Topics │ ├── Decisions │ ├── Questions │ ├── Tasks │ ├── Research │
└── Requirements │ ├── Conversations ├── Files └── Timeline

A project graph becomes the source of truth.

------------------------------------------------------------------------

# Major Technical Challenges

## 1. Project Model

Design a data model that works for many domains without becoming too
generic.

## 2. Knowledge Extraction

Automatically identify:

-   decisions
-   tasks
-   questions
-   requirements

from natural conversations.

## 3. Knowledge Evolution

Projects evolve.

The system must update previous decisions instead of endlessly appending
new information.

Maintain history.

## 4. Retrieval

Do not send an entire project to the LLM.

Retrieve only relevant artifacts based on the current query.

## 5. Recommendation Engine

Recommend logical next actions based on project state rather than
generic AI suggestions.

## 6. Trust

Never silently modify project knowledge.

Show proposed changes and maintain a full history.

------------------------------------------------------------------------

# MVP Scope

Keep the first version intentionally small.

Supported artifacts:

-   Topics
-   Decisions
-   Questions
-   Tasks
-   Conversations

Workflow:

1.  User chats with AI.
2.  AI proposes structured updates.
3.  User reviews suggestions.
4.  Accepted changes become part of project memory.

No autonomous editing.

------------------------------------------------------------------------

# Long-Term Vision

The application becomes an AI operating system for complex projects.

The persistent project graph is the core asset.

Different LLM providers (ChatGPT, Claude, Gemini, local models) become
interchangeable reasoning engines operating on the same project
knowledge.

------------------------------------------------------------------------

# Key Differentiators

-   Projects instead of chats
-   Persistent structured knowledge
-   Decision history
-   AI-guided next actions
-   Vendor-independent AI layer
-   Living project memory

------------------------------------------------------------------------

# Guiding Philosophy

Conversations are temporary.

Knowledge is permanent.

The value of the product is not the AI model itself, but the evolving
project memory that helps users complete complex, long-running projects.
