# Send, Swap & Bridge

All outbound transactions follow the same pattern: **Quote** -> **Sign** -> **Submit**.

## Send Tokens

### Step 1: Create a Send Quote

A quote locks the required funds and returns signing data.

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{
    "type": "send",
    "chainId": 8453,
    "token": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "amount": "1000000",
    "decimals": 6,
    "destinationAddress": "0xRecipientAddress"
  }' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/quote
```

| Field | Description |
|-------|-------------|
| `type` | `"send"` |
| `chainId` | Chain ID (must support Porto) |
| `token` | Token contract address (`0x0000...0000` for native ETH) |
| `amount` | Amount in smallest unit (stringified bigint) |
| `decimals` | Token decimals (0-255) |
| `destinationAddress` | Recipient address (`0x...`) or ENS name |
| `ttl` | Optional lock TTL in seconds (default: 86400, max: 86400) |

Response:
```json
{
  "quoteId": "uuid",
  "intents": [...],
  "delegations": [...],
  "expiresAt": "2025-01-02T00:00:00.000Z",
  "signature": "0x...",
  "resolvedDestination": "0xRecipientAddress",
  "selfSend": false
}
```

### Step 2: Sign Intents and Delegations

Each intent must be signed with the **derived stealth private key** — not `p_spend` directly. The intent's `eoa` is a stealth address, and the server verifies that the signature recovers to it.

The signing flow:
1. Read `derivationNonce` from each intent
2. Reconstruct the ephemeral key using `deriveDeterministicEphemeralKey(childViewingNode, derivationNonce)`
3. Compute the stealth private key using `genStealthPrivateKey({ p_spend, P_derived })`
4. Sign the intent (EIP-712 typed data) and delegation (EIP-7702 authorization) with the stealth key

The server sends `executionData` (ABI-encoded calls). For EIP-712, decode it back into a `Call[]` array using `decodeAbiParameters`.

See [Agent Setup: Signing](agent-setup.md#3-sign-transactions) for the full implementation with code examples.

### Step 3: Submit the Signed Transaction

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{
    "quoteId": "uuid-from-quote",
    "intents": [...],
    "delegations": [...]
  }' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/submit
```

Response:
```json
{
  "success": true,
  "quoteId": "uuid",
  "status": "submitted",
  "message": "Transaction relayed"
}
```

The server relays the transaction on-chain — the user pays no gas directly.

### Cancel a Quote (Unlock)

If the user decides not to send, release the locked funds:

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"quoteId": "uuid-from-quote"}' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/unlock
```

```json
{
  "success": true,
  "message": "Quote unlocked"
}
```

## Swap Tokens

### Preview (No Lock)

Get a price quote without locking funds:

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
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/swap-preview
```

```json
{
  "expectedOutput": "500000000000000",
  "minimumOutput": "497500000000000",
  "outputToken": "0x4200000000000000000000000000000000000006",
  "outputDecimals": 18,
  "outputSymbol": "WETH",
  "routing": "CLASSIC",
  "slippageBps": 50,
  "feeEstimate": "50000000000000",
  "protocolFeeBps": 0,
  "protocolFeeAmount": "0",
  "priceImpact": "0.01"
}
```

### Execute Swap (Quote -> Sign -> Submit)

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{
    "type": "swap",
    "chainId": 8453,
    "tokenIn": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "tokenOut": "0x4200000000000000000000000000000000000006",
    "amountIn": "1000000",
    "slippageBps": 50
  }' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/quote
```

Swap quote response includes pricing info:
```json
{
  "quoteId": "uuid",
  "intents": [...],
  "delegations": [...],
  "expiresAt": "2025-01-02T00:00:00.000Z",
  "signature": "0x...",
  "expectedOutput": "500000000000000",
  "minimumOutput": "497500000000000",
  "outputToken": "0x4200000000000000000000000000000000000006",
  "outputDecimals": 18,
  "outputSymbol": "WETH",
  "outputRecipient": "0x...",
  "slippageBps": 50,
  "routing": "CLASSIC",
  "protocolFeeBps": 0,
  "protocolFeeAmount": "0"
}
```

Then sign and submit using the same `POST /v1/accounts/{id}/submit` endpoint as sends.

## Bridge Tokens (Cross-Chain Swap)

Bridging uses the swap quote with an additional `tokenOutChainId`:

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{
    "type": "swap",
    "chainId": 1,
    "tokenIn": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "tokenOut": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "amountIn": "1000000",
    "slippageBps": 50,
    "tokenOutChainId": 8453
  }' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/quote
```

This bridges USDC from Ethereum to Base. The response includes `estimatedFillTimeMs` and `fillDeadline`.

## Max Spendable

Calculate the maximum amount after deducting relay fees. The `type` field is required — swap has higher fees than send.

```bash
# Max for a send
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"chainId": 8453, "token": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "type": "send"}' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/max-spendable

# Max for a swap
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"chainId": 8453, "token": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", "type": "swap"}' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/max-spendable
```

| Field | Required | Description |
|-------|----------|-------------|
| `chainId` | Yes | Chain ID |
| `token` | Yes | Token address (`0x...`) |
| `type` | Yes | `"send"` or `"swap"` (swap has higher fees) |

```json
{
  "maxAmount": "950000",
  "feeEstimate": "50000",
  "spendableCount": 3
}
```

## Quote Signer Public Key

Verify quote authenticity by checking the server's P-256 ECDSA signature:

```bash
curl https://api.clkd.xyz/v1/.well-known/quote-signer-public-key
```

```json
{
  "publicKey": "04...",
  "format": "hex",
  "curve": "P-256",
  "algorithm": "ECDSA"
}
```

## Group Approvals (Multi-Sig)

For accounts with threshold > 1, quotes require multiple signers.

### List Pending Approvals

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/quotes
```

### Submit Signer's Signatures

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "signerAddress": "0xSignerAddress",
    "signatures": [
      {"intentIndex": 0, "signature": "0x..."},
      {"intentIndex": 1, "signature": "0x..."}
    ]
  }' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/quotes/$QUOTE_ID/signatures
```

When enough signers have signed (threshold met), the transaction is automatically relayed.
