# Balances & Activities

## Balances

### All Balances (All Chains)

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/balance
```

```json
{
  "balances": [
    {
      "chainId": 8453,
      "chainName": "Base",
      "token": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      "tokenSymbol": "USDC",
      "decimals": 6,
      "logoUrl": "https://...",
      "available": "1000000",
      "pending": "500000",
      "usdAmount": 1.50,
      "spam": false
    }
  ],
  "totalUsdAmount": 1.50
}
```

| Field | Description |
|-------|-------------|
| `available` | Spendable balance in smallest unit (stringified bigint) |
| `pending` | In-flight amount (locked by quotes or awaiting confirmation) |
| `usdAmount` | USD value (`null` if price unavailable) |
| `spam` | Whether the token is flagged as spam |

### Chain-Specific Balances

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/balance/8453
```

Same response shape, filtered to the given chain.

### Single Token Balance

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/balance/8453/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
```

Returns a single balance object (not wrapped in an array). Returns a zero-balance object if the token has never been received.

## Activities (Transaction History)

### Confirmed Activities

Cursor-based pagination over on-chain transactions:

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  "https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/activities?limit=20"
```

```json
{
  "activity": [
    {
      "txHash": "0x...",
      "chainId": 8453,
      "chainName": "Base",
      "activityType": "SEND",
      "date": "2025-01-01T12:00:00.000Z",
      "fee": {
        "tokenAddress": "0x0000000000000000000000000000000000000000",
        "decimals": 18,
        "tokenSymbol": "ETH",
        "logoUrl": "https://...",
        "value": "1000000000000000",
        "usdAmount": 2.50
      },
      "isFailure": false,
      "isLikelySpam": false,
      "transfer": {
        "tokenAddress": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        "decimals": 6,
        "tokenSymbol": "USDC",
        "logoUrl": "https://...",
        "fromAddress": "0x...",
        "toAddress": "0x...",
        "value": "1000000",
        "usdAmount": 1.00
      }
    }
  ],
  "pagination": {
    "limit": 20,
    "nextCursor": "base64-cursor-string"
  }
}
```

**Activity types** — the response uses a discriminated union:

| `activityType` | Present field | Description |
|----------------|---------------|-------------|
| `SEND` | `transfer` | Outbound token transfer |
| `RECEIVE` | `transfer` | Inbound token transfer |
| `SELF` | `transfer` | Transfer to own stealth address |
| `SWAP` | `swap` | Token swap (source + dest info) |
| `BRIDGE` | `bridge` | Cross-chain bridge (source + dest + chain info) |

Only the relevant field is present — `swap` and `bridge` are omitted (not null) for SEND/RECEIVE/SELF activities.

#### Swap Activity Shape

```json
{
  "activityType": "SWAP",
  "swap": {
    "sourceTokenAddress": "0x...",
    "sourceDecimals": 6,
    "sourceTokenSymbol": "USDC",
    "sourceLogoUrl": "https://...",
    "sourceAmount": "1000000",
    "sourceUsdAmount": 1.00,
    "destTokenAddress": "0x...",
    "destTokenSymbol": "WETH",
    "destDecimals": 18,
    "destLogoUrl": "https://...",
    "destAmount": "500000000000000",
    "destUsdAmount": 0.50,
    "outputRecipient": "0x..."
  }
}
```

#### Bridge Activity Shape

```json
{
  "activityType": "BRIDGE",
  "bridge": {
    "sourceTokenAddress": "0x...",
    "sourceDecimals": 6,
    "sourceTokenSymbol": "USDC",
    "sourceLogoUrl": "https://...",
    "sourceAmount": "1000000",
    "sourceUsdAmount": 1.00,
    "destTokenAddress": "0x...",
    "destTokenSymbol": "USDC",
    "destDecimals": 6,
    "destLogoUrl": "https://...",
    "destAmount": "1000000",
    "destUsdAmount": 1.00,
    "outputRecipient": "0x...",
    "bridgeStatus": "completed",
    "destChainId": 8453,
    "destChainName": "Base",
    "estimatedFillTimeMs": 120000
  }
}
```

Bridge statuses: `pending` -> `confirmed_source` -> `completed` | `failed` | `expired`.

#### Pagination

Pass `nextCursor` to get the next page:

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  "https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/activities?limit=20&cursor=base64-cursor-string"
```

When `nextCursor` is `null`, there are no more results.

### Pending Activities

In-flight transactions (queued, pending, stuck, recently confirmed):

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/activities/pending
```

```json
{
  "pending": [
    {
      "txHash": "0x...",
      "quoteId": "uuid",
      "chainId": 8453,
      "chainName": "Base",
      "activityType": "send",
      "status": "pending",
      "date": "2025-01-01T12:00:00.000Z",
      "fee": {...},
      "transfer": {...}
    }
  ]
}
```

Statuses: `queued` -> `pending` -> `confirmed` | `stuck`. Recently confirmed transactions stay for ~5 minutes for UI continuity.

## Token Catalog

### Full Token List

```bash
curl https://api.clkd.xyz/v1/token-catalog
```

```json
{
  "tokens": [
    {
      "address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      "symbol": "USDC",
      "name": "USD Coin",
      "decimals": 6,
      "chainId": 8453,
      "logoURI": "https://...",
      "isClanker": false
    }
  ],
  "pinnedSymbols": ["ETH", "USDC", "USDT"],
  "testnetToMainnet": {"11155111": 1, "84532": 8453}
}
```

### Token Lookup

Look up any token by contract address:

```bash
curl "https://api.clkd.xyz/v1/token-lookup?address=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913&chainId=8453"
```

```json
{
  "address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  "symbol": "USDC",
  "name": "USD Coin",
  "decimals": 6,
  "chainId": 8453,
  "logoURI": "https://...",
  "isClanker": false
}
```

## Supported Chains

```bash
curl https://api.clkd.xyz/v1/supported-chains
```

```json
[
  {
    "name": "Base",
    "chainId": 8453,
    "isTestnet": false,
    "explorerUrl": "https://basescan.org",
    "explorerTxPath": "/tx/",
    "mainnetChainId": 8453,
    "logoBaseName": "base",
    "isSquareLogo": false
  }
]
```
