# Security Model

## Stealth Addresses

Cloaked uses stealth addresses to provide on-chain privacy:

1. **Each payment gets a unique address** — when someone sends tokens, a fresh one-time address is derived. The address cannot be linked back to the recipient's identity on-chain.
2. **Sender sees only the one-time address** — not the recipient's account or other payment addresses.
3. **Only the recipient can spend** — stealth addresses are derived from the recipient's key material, so only they can authorize transactions from those addresses.

## Key Material

- **Stealth material** is HPKE-encrypted before being sent to the server during account creation. The server stores encrypted keys and uses them for stealth address derivation.
- **Private spending keys** never leave the client. The server cannot sign transactions — only the user's device can.
- **Agents using API keys** can read balances, generate receive addresses, and create quotes. To sign and submit transactions, the agent must hold `p_spend` and `child_p_view` — see [Agent Setup](agent-setup.md).

## Agent Safety Rules

When building integrations:

1. **Never store or log private keys.** API keys authenticate to the Cloaked server — they are not wallet keys.
2. **Never expose stealth material, ciphertext, or encapsulated keys** in logs, responses, or error messages.
3. **Always use HTTPS.** The API enforces TLS — never downgrade to HTTP.
4. **Validate all addresses** with EIP-55 checksumming before sending transactions.
5. **Verify token decimals** before constructing amounts. Sending 1 USDC requires `"1000000"` (6 decimals), not `"1000000000000000000"` (18 decimals). Getting this wrong means sending 1 trillion times too much or too little.
6. **Use idempotency keys** on `POST /v1/accounts/{id}/quote` and `POST /v1/accounts/{id}/submit` to prevent duplicate transactions on network retries.
7. **Release locks promptly** — if a quote won't be submitted, call `POST /v1/accounts/{id}/unlock` to free the funds. Locks auto-expire after the TTL (default 24h), but leaving funds locked blocks subsequent transactions.
8. **Respect rate limits.** Back off on `429` responses. Hitting rate limits repeatedly may result in temporary blocks.

## Error Handling

All API errors return a consistent shape:

```json
{
  "error": "Human-readable error type",
  "message": "Detailed explanation",
  "code": "MACHINE_READABLE_CODE"
}
```

| Status | Meaning | Action |
|--------|---------|--------|
| `400` | Validation error | Fix the request — check required fields, formats, amounts |
| `401` | Missing or invalid auth | Refresh JWT or check API key |
| `404` | Resource not found | Verify account ID, quote ID, or token address |
| `422` | Semantically invalid | Request is well-formed but logically wrong (e.g., expired nonce) |
| `429` | Rate limited | Back off and retry after the indicated window |
| `502` | Upstream failure | Retry with exponential backoff (e.g., Uniswap API down) |
| `503` | Service unavailable | Retry with backoff — the service is temporarily overloaded |

## Privacy Considerations

- **Balance queries** reveal nothing on-chain — they query the Cloaked server's internal index.
- **Transaction history** is only visible to authenticated account holders — the server does not expose activity publicly.
- **ENS resolution** generates a fresh stealth address per lookup, so resolving `alice.clkd.eth` twice produces two different addresses.
- **On-chain observers** see individual stealth addresses receiving/sending funds but cannot link them to a single identity without the viewing key.
