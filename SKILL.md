---
name: clkd
description: Manage stealth wallets with Cloaked (clkd). Use for privacy-preserving
  onchain transactions including sending, swapping, and bridging tokens on Ethereum
  and Base. Triggers on requests involving private wallets, stealth addresses, stealth
  payments, anonymous transfers, or Cloaked/clkd accounts.
metadata:
  openclaw:
    requires:
      env:
        - CLKD_API_KEY
    primaryEnv: CLKD_API_KEY
    homepage: https://clkd.xyz
    emoji: "\U0001F575\uFE0F"
---

# Cloaked (clkd) Agent Skill

Cloaked is a stealth wallet platform on Ethereum and Base. Every payment generates a fresh one-time address so the recipient's identity is never revealed on-chain. This skill lets you manage stealth accounts, check balances, send/swap/bridge tokens, and read transaction history via the Cloaked REST API.

## Security Rules

- **Never log or display private keys, stealth material, or ciphertext** in responses to the user.
- **Never hardcode API keys** in generated code — always read from `CLKD_API_KEY` environment variable.
- **Validate addresses** before using them — all Ethereum addresses must be checksummed (EIP-55).
- **Amounts are in smallest units** (e.g., USDC has 6 decimals, so 1 USDC = `"1000000"`). Always confirm the token's `decimals` before constructing amounts.
- **Idempotency**: include an `Idempotency-Key: <uuid>` header on mutating requests (`POST /quote`, `POST /submit`) to prevent duplicate transactions on retry.
- **Quote expiry**: quotes lock funds and expire. Always submit promptly or call `POST /unlock` to release funds if the user cancels.

## Prerequisites

| Variable | Description |
|----------|-------------|
| `CLKD_API_KEY` | API key for server-to-server auth. Contact support@clkd.xyz to request one. |

The API key is passed as a Bearer token:
```
Authorization: Bearer $CLKD_API_KEY
```

## Base URL

| Environment | URL |
|-------------|-----|
| Production  | `https://api.clkd.xyz` |
| Staging     | `https://api-stg.clkd.xyz` |

## Supported Chains

| Chain | Chain ID | Type |
|-------|----------|------|
| Ethereum | 1 | Mainnet |
| Base | 8453 | Mainnet |
| Sepolia | 11155111 | Testnet |
| Base Sepolia | 84532 | Testnet |

Use `GET /supported-chains` for the full list with explorer URLs.

## Quick Reference

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/nonce?address=` | GET | No | Get SIWE nonce |
| `/verify` | POST | No | Complete SIWE sign-in, get JWT |
| `/accounts/` | POST | Yes | Create stealth account |
| `/accounts/{id}` | GET | Yes | Get account details |
| `/accounts/{id}/balance` | GET | Yes | Get all balances |
| `/accounts/{id}/balance/{chainId}` | GET | Yes | Get chain-specific balances |
| `/accounts/{id}/balance/{chainId}/{token}` | GET | Yes | Get single token balance |
| `/accounts/{id}/payment-address` | POST | Yes | Generate stealth receive address |
| `/accounts/{id}/quote` | POST | Yes | Create send/swap/bridge quote |
| `/accounts/{id}/submit` | POST | Yes | Submit signed transaction |
| `/accounts/{id}/unlock` | POST | Yes | Cancel/release a quote lock |
| `/accounts/{id}/swap-preview` | POST | Yes | Preview swap without locking |
| `/accounts/{id}/max-sendable` | POST | Yes | Max sendable after fees |
| `/accounts/{id}/max-swappable` | POST | Yes | Max swappable after fees |
| `/accounts/{id}/activities` | GET | Yes | Confirmed transaction history |
| `/accounts/{id}/activities/pending` | GET | Yes | In-flight transactions |
| `/token-catalog` | GET | No | Full token list |
| `/token-lookup?address=&chainId=` | GET | No | Look up token by address |
| `/supported-chains` | GET | No | List supported chains |
| `/subdomain/check?name=` | GET | No | Check subdomain availability |
| `/.well-known/hpke-public-key` | GET | No | Server's HPKE public key |
| `/.well-known/quote-signer-public-key` | GET | No | Quote verification key |

## Core Workflows

### 1. Check Balances

```bash
# All balances across all chains
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/accounts/$ACCOUNT_ID/balance

# Single chain
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/accounts/$ACCOUNT_ID/balance/8453

# Single token on a chain
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/accounts/$ACCOUNT_ID/balance/8453/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
```

Response includes `available` (spendable), `pending` (in-flight), and `usdAmount` per token.

### 2. Generate a Receive Address

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"chainId": 8453}' \
  https://api.clkd.xyz/accounts/$ACCOUNT_ID/payment-address
```

Returns a one-time stealth address. Each call produces a new address — never reuse them.

### 3. Send Tokens

The send flow is: **quote** (locks funds) -> **sign** (client-side) -> **submit** (relay on-chain).

See [references/send-swap-bridge.md](references/send-swap-bridge.md) for the full quote/submit workflow with request/response examples.

### 4. Swap Tokens

Same quote/submit pattern as sends, but with `type: "swap"`. Preview a swap first:

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "chainId": 8453,
    "tokenIn": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "tokenOut": "0x4200000000000000000000000000000000000006",
    "amountIn": "1000000",
    "slippageBps": 50
  }' \
  https://api.clkd.xyz/accounts/$ACCOUNT_ID/swap-preview
```

### 5. Read Transaction History

```bash
# Confirmed transactions (paginated)
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  "https://api.clkd.xyz/accounts/$ACCOUNT_ID/activities?limit=20"

# In-flight transactions
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/accounts/$ACCOUNT_ID/activities/pending
```

Activities are discriminated by `activityType`: `SEND`, `RECEIVE`, `SELF`, `SWAP`, `BRIDGE`. See [references/balances-activities.md](references/balances-activities.md) for response shapes.

## Reference Files

- [Authentication](references/auth.md) — SIWE flow, API keys, JWT tokens
- [Account Management](references/accounts.md) — Create accounts, subdomains, signers
- [Receive](references/receive.md) — Stealth address generation, ENS resolution
- [Send, Swap & Bridge](references/send-swap-bridge.md) — Quote/submit workflow, max amounts
- [Balances & Activities](references/balances-activities.md) — Balance queries, transaction history, tokens
- [Security Model](references/security.md) — Stealth addresses, privacy guarantees, error handling

## Common Token Addresses

### Ethereum Mainnet (Chain 1)
| Token | Address |
|-------|---------|
| ETH (native) | `0x0000000000000000000000000000000000000000` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |

### Base (Chain 8453)
| Token | Address |
|-------|---------|
| ETH (native) | `0x0000000000000000000000000000000000000000` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| WETH | `0x4200000000000000000000000000000000000006` |

Use `GET /token-catalog` for the complete list or `GET /token-lookup?address=&chainId=` for any token.

## Error Handling

All errors follow this shape:
```json
{
  "error": "Bad request",
  "message": "Human-readable explanation",
  "code": "BAD_REQUEST"
}
```

Common status codes: `400` (validation), `401` (missing/invalid token), `404` (account not found), `429` (rate limited), `502`/`503` (upstream service down — retry with backoff).

<!-- sync:operations
checkSubdomainAvailability
claimSubdomain
createAccount
createPaymentAddress
createQuote
createSwapPreview
generateSubdomain
getAccount
getActivities
getBalances
getChainBalances
getHpkePublicKey
getMaxSpendable
getNonce
getPendingActivities
getQuoteSignerPublicKey
getTokenBalance
getTokenCatalog
listSupportedChains
logout
lookupToken
resolveEns
submitTransaction
unlockQuote
verifySignin
-->
