# Cloaked Agent Skill

> **This skill is in active development and has not been audited. Use at your own risk.** APIs, schemas, and signing flows may change without notice. Do not use with mainnet funds unless you understand the risks.

Agent skill for [Cloaked](https://clkd.xyz) — privacy-preserving stealth wallets on Ethereum and Base.

This skill teaches AI agents how to interact with the Cloaked API to manage stealth accounts, check balances, send/swap/bridge tokens, and read transaction history.

## What is Cloaked?

Cloaked is a stealth wallet platform. Every payment generates a fresh one-time address so the recipient's identity is never revealed on-chain. It supports Ethereum and Base with native token sends, swaps (via Uniswap), and cross-chain bridges.

## Usage

### With Claude Code / OpenClaw

Add this skill to your agent:

```bash
clawhub install cloakedxyz/clkd-agent-skill
```

Or copy the `SKILL.md` and `references/` directory into your project's `.claude/skills/` folder.

### With Other Agent Frameworks

The skill is framework-agnostic Markdown. Point your agent at `SKILL.md` as a system prompt or knowledge file — it contains structured API documentation with curl examples that any LLM can follow.

## Prerequisites

Set the `CLKD_API_KEY` environment variable with your API key. Contact [support@clkd.xyz](mailto:support@clkd.xyz) to request one.

## Structure

```
SKILL.md                          # Main skill definition (loaded by the agent)
references/
  auth.md                         # Authentication (SIWE, API keys, JWTs)
  accounts.md                     # Account creation, subdomains, signers
  receive.md                      # Stealth address generation, ENS
  send-swap-bridge.md             # Quote/submit workflow, swaps, bridges
  balances-activities.md          # Balance queries, transaction history
  security.md                     # Privacy model, safety rules, error handling
```

## API Documentation

Full interactive API docs: [clkd.xyz/docs/api-reference](https://clkd.xyz/docs/api-reference)

OpenAPI spec: [clkd.xyz/openapi.json](https://clkd.xyz/openapi.json)

## License

MIT
