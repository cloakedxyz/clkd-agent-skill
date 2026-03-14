# Receive

## Generate a Stealth Payment Address

Each call generates a fresh one-time stealth address. Senders transfer tokens to this address — on-chain, the address is unlinkable to the recipient's account.

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{}' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/payment-address
```

```json
{
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD38",
  "nonce": "42"
}
```

| Field | Description |
|-------|-------------|
| `address` | One-time stealth address for receiving |
| `nonce` | Derivation nonce (stringified bigint) |

**Important:**
- Never reuse a stealth address — generate a new one for each payment
- Stealth addresses work on any supported chain (they are cross-chain compatible)
- Funds sent to the address will appear in the account's balance once indexed

## ENS Resolution

Users with a subdomain (e.g., `alice.clkd.eth`) can receive payments via ENS. The ENS gateway automatically generates a fresh stealth address for each resolution.

### How It Works

1. Sender resolves `alice.clkd.eth` via standard ENS tooling (ethers, viem, wagmi)
2. ENS calls the EIP-3668 CCIP-Read gateway at `POST /ens/gateway/{sender}`
3. Gateway generates a fresh stealth address and returns a signed response
4. Sender's wallet gets back a one-time address to send to

This is infrastructure — agents and clients don't call the gateway directly. They use standard ENS resolution which triggers it automatically.

### Public Receive Page

In development, users have a receive page at:
```
GET /u/{username}
```

This renders an HTML page with a QR code and stealth address. In production, the receive page is served at `https://{username}.clkd.id`.

Supports invoice parameters:
```
/u/alice?amount=10&token=USDC&chain=base
```
