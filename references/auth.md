# Authentication

The Cloaked API supports two authentication methods:

## API Key (Recommended for Agents)

Long-lived keys for server-to-server integrations. Pass as a Bearer token:

```bash
curl -H "Authorization: Bearer $CLKD_API_KEY" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/balance
```

Contact support@clkd.xyz to request an API key.

## JWT via Sign-In with Ethereum (SIWE)

Short-lived session tokens obtained through a two-step flow. This is the method used by the Cloaked wallet app.

**Important:** The address used for SIWE must be derived from your private spending key (`privateKeyToAccount(p_spend).address`), NOT your connected wallet address.

### Step 1: Get a Nonce

```bash
curl "https://api.clkd.xyz/v1/nonce?address=0xYourAuthAddress"
```

Response: a plain string nonce (expires in 5 minutes).

```
"a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
```

### Step 2: Sign and Verify

Construct a SIWE message with the nonce, sign it with the auth private key, and submit:

```bash
curl -X POST https://api.clkd.xyz/v1/verify \
  -H "Content-Type: application/json" \
  -d '{
    "message": "clkd.xyz wants you to sign in with your Ethereum account:\n0xYourAuthAddress\n\nSign in to Cloaked\n\nURI: https://clkd.xyz\nVersion: 1\nChain ID: 1\nNonce: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6\nIssued At: 2025-01-01T00:00:00.000Z",
    "signature": "0x..."
  }'
```

Response:
```json
{
  "ok": true,
  "address": "0xYourAuthAddress",
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "accountId": "550e8400-e29b-41d4-a716-446655440000"
}
```

- `token` — JWT to use as Bearer token (short-lived)
- `accountId` — the stealth account ID (`null` if user hasn't registered yet)

### Logout

```bash
curl -X POST https://api.clkd.xyz/v1/logout \
  -H "Authorization: Bearer $TOKEN"
```

Clears server-side cache. Discard the JWT client-side as well.

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| `GET /v1/nonce` | 20/min |
| `POST /v1/verify` | 10/min |
| `GET /v1/accounts/{id}/balance` | 60/min |
| ENS gateway | 15/min |
| Most other endpoints | No specific limit (global limits apply) |

Rate limit responses return `429` with a `message` describing the limit.

## HPKE Public Key

The server's HPKE key is needed for encrypting stealth material during account creation:

```bash
curl https://api.clkd.xyz/v1/.well-known/hpke-public-key
```

```json
{
  "publicKey": "0x...",
  "publicKeyBase64": "...",
  "format": "hex",
  "kem": "X25519-HKDF-SHA256",
  "aead": "AES-128-GCM"
}
```
