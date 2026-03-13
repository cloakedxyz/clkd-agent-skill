# Account Management

## Create Account

Register a new stealth account by submitting HPKE-encrypted key material. Requires a JWT from the SIWE flow.

```bash
curl -X POST https://api.clkd.xyz/v1/accounts/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ciphertext": "base64-encoded-encrypted-payload",
    "encapsulatedKey": "base64-encoded-hpke-encapsulated-key",
    "inviteCode": "optional-invite-code"
  }'
```

Response:
```json
{
  "accountId": "550e8400-e29b-41d4-a716-446655440000",
  "alreadyExisted": false
}
```

- `inviteCode` is required when gated access is enabled
- If the address already has an account, `alreadyExisted: true` and the existing `accountId` is returned

### Validate Invite Code (before creating)

```bash
curl "https://api.clkd.xyz/v1/invite-codes/validate?code=MY_CODE"
```

```json
{
  "valid": true,
  "reservedSubdomain": "alice"
}
```

## Get Account

```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID
```

```json
{
  "accountId": "550e8400-e29b-41d4-a716-446655440000",
  "address": "0x...",
  "isRegistered": true,
  "subdomain": "alice",
  "lastConsumedNonce": 42
}
```

- `isRegistered` — whether the account is fully registered (always `true` for authenticated requests)
- `subdomain` — claimed ENS name (e.g., `alice` means `alice.clkd.eth`), or `null`
- `lastConsumedNonce` — last stealth address derivation nonce (`null` if none generated)

## Subdomains

### Check Availability

```bash
curl "https://api.clkd.xyz/v1/subdomain/check?name=alice"
```

```json
{
  "available": true
}
```

If unavailable: `{ "available": false, "reason": "taken" }` or `"blocked"`.

### Claim Subdomain

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"subdomain": "alice"}' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/subdomain
```

```json
{
  "success": true,
  "message": "Subdomain claimed",
  "subdomain": "alice"
}
```

The user can then receive payments at `alice.clkd.eth`.

### Generate Random Subdomain

```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/subdomain/generate
```

```json
{
  "subdomain": "example-123.clkd.eth"
}
```

Not reserved — call `setSubdomain` to claim.

## Signers

Accounts support multiple signers for multi-device or group (multi-sig) use.

### List Signers

```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/signers
```

```json
{
  "signers": [
    {
      "signerId": "uuid",
      "address": "0x...",
      "enrolledAt": "2025-01-01T00:00:00.000Z",
      "ownerId": null
    }
  ]
}
```

### Add Signer

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ciphertext": "base64-encrypted",
    "encapsulatedKey": "base64-key"
  }' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/signers
```

```json
{
  "signerId": "new-signer-uuid"
}
```

### Get Account Config (Signer History)

```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/config
```

```json
{
  "configs": [
    {
      "id": "uuid",
      "version": 1,
      "threshold": 1,
      "signerIds": ["signer-uuid-1"],
      "status": "active",
      "createdAt": "2025-01-01T00:00:00.000Z",
      "retiredAt": null
    }
  ]
}
```

## Recovery (Teams & Orgs)

Recovery hierarchy: **Org** -> **Team** -> **Account**. Without a team, accounts can only be recovered by their own signers.

### Create Team

```bash
curl -X POST https://api.clkd.xyz/v1/teams/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Engineering",
    "accounts": [{"accountId": "uuid", "label": "Alice"}]
  }'
```

### Create Org

```bash
curl -X POST https://api.clkd.xyz/v1/orgs/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Acme Corp"}'
```

See the full API docs for `GET /v1/teams/{id}`, `POST /v1/teams/{id}/accounts`, `GET /v1/orgs/{id}`.
