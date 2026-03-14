# Agent Setup: Keys, Enrollment & Signing

This guide covers everything an agent needs to generate key material, enroll as a signer on a Cloaked account, and sign transactions.

## Dependencies

```bash
npm install @cloakedxyz/clkd-stealth viem @scure/bip32
```

## 1. Generate Key Material

Cloaked uses two key pairs — **spend** (authorizes transactions) and **view** (derives stealth addresses). Generate them from random entropy:

```javascript
import { genKeys } from '@cloakedxyz/clkd-stealth/dist/client/genKeys.js';
import { HDKey } from '@scure/bip32';
import { randomBytes } from 'crypto';

// Two 32-byte random secrets — store these securely, they are your root material
const spendSecret = '0x' + randomBytes(32).toString('hex');
const viewSecret = '0x' + randomBytes(32).toString('hex');

// Derive key pairs: p_ = private, P_ = public (uncompressed)
const { p_spend, P_spend, p_view, P_view } = genKeys({ spendSecret, viewSecret });

// Derive the child viewing key (used for stealth address derivation)
const masterNode = HDKey.fromMasterSeed(Buffer.from(p_view.slice(2), 'hex'));
const childNode = masterNode.derive('m/0');
const child_p_view = '0x' + Buffer.from(childNode.privateKey).toString('hex');
```

**What to store (agent-side):**

| Key | Purpose | Security |
|-----|---------|----------|
| `p_spend` | Signs transactions | Critical — never expose |
| `child_p_view` | Derives ephemeral keys for signing | Critical — never expose |
| `spendSecret` / `viewSecret` | Root entropy for key recovery | Critical — never expose |

**What to send to the server:**

| Key | Purpose |
|-----|---------|
| `P_spend` | Public spending key (uncompressed, 65 bytes) |
| `P_view` | Public viewing key (uncompressed, 65 bytes) |
| `child_p_view` | Child viewing private key (server needs this for address derivation) |

## 2. Enroll as a Signer

Once you have an account (provisioned via API key), enroll your key material as a signer. This uses the plaintext enrollment path — no HPKE encryption needed.

```bash
curl -X POST -H "Authorization: Bearer $CLKD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "P_spend": "0x04...",
    "P_view": "0x04...",
    "child_p_view": "0x..."
  }' \
  https://api.clkd.xyz/v1/accounts/$ACCOUNT_ID/signers
```

```json
{
  "signerId": "new-signer-uuid"
}
```

After enrollment, the account can generate stealth addresses and create quotes.

## 3. Sign Transactions

The transaction flow is: **Quote** -> **Sign** -> **Submit**. The critical detail is that intents must be signed with the *derived stealth private key*, not `p_spend` directly.

### Why? Stealth Address Signing

Each intent's `eoa` field is a stealth address — a one-time address derived from your `P_spend` and an ephemeral key. The server verifies that the signature recovers to this stealth address, so you must sign with the corresponding stealth private key.

### Step-by-Step Signing

```javascript
import { privateKeyToAccount } from 'viem/accounts';
import { decodeAbiParameters, parseAbiParameters, hexToBytes } from 'viem';
import { HDKey } from '@scure/bip32';
import { deriveDeterministicEphemeralKey } from '@cloakedxyz/clkd-stealth/dist/shared/deriveDeterministicEphemeralKey.js';
import { genStealthPrivateKey } from '@cloakedxyz/clkd-stealth/dist/client/genStealthPrivateKey.js';

// Your stored keys
const p_spend = '0x...';       // private spending key
const child_p_view = '0x...';  // child viewing private key

// Build the child viewing HD node (needed for ephemeral key derivation)
const childViewingNode = HDKey.fromMasterSeed(hexToBytes(child_p_view));
```

#### A. Derive the Stealth Private Key

Each intent in the quote response includes a `derivationNonce` — the nonce used when the server generated the stealth address. Use it to reconstruct the ephemeral key and compute the stealth private key:

```javascript
function deriveStealthAccount(intent, p_spend, childViewingNode) {
  const derivNonce = BigInt(intent.derivationNonce);

  // 1. Reconstruct the ephemeral private key
  const { p_derived } = deriveDeterministicEphemeralKey(childViewingNode, derivNonce);

  // 2. Get the ephemeral PUBLIC key (uncompressed, 0x04...)
  const P_derived = privateKeyToAccount(p_derived).publicKey;

  // 3. Compute stealth private key: p_stealth = (p_spend * hash(ECDH)) mod n
  const { p_stealth } = genStealthPrivateKey({ p_spend, P_derived });

  // 4. Create a viem account — its .address should match intent.eoa
  return privateKeyToAccount(p_stealth);
}
```

#### B. Sign Intents (EIP-712)

The server sends `executionData` (ABI-encoded calls). For EIP-712 signing, decode it back into the `Call[]` array:

```javascript
function decodeExecutionData(executionData) {
  const result = decodeAbiParameters(
    parseAbiParameters('(address to, uint256 value, bytes data)[]'),
    executionData
  );
  return result[0].map(c => ({ to: c.to, value: c.value, data: c.data }));
}

// For each intent in quote.intents:
const stealthAccount = deriveStealthAccount(intent, p_spend, childViewingNode);

// Verify the derived address matches what the server expects
if (stealthAccount.address.toLowerCase() !== intent.eoa.toLowerCase()) {
  throw new Error('Stealth key derivation mismatch');
}

// Strip EIP712Domain from types (viem adds it automatically)
const { EIP712Domain, ...sigTypes } = intent.types;

// Build the EIP-712 message
const message = {
  multichain: intent.isMultichain,
  eoa: intent.eoa,
  calls: decodeExecutionData(intent.executionData),
  nonce: BigInt(intent.nonce),
  payer: intent.payer,
  paymentToken: intent.paymentToken,
  paymentMaxAmount: BigInt(intent.paymentMaxAmount),
  combinedGas: BigInt(intent.combinedGas),
  encodedPreCalls: intent.encodedPreCalls,
  encodedFundTransfers: intent.encodedFundTransfers,
  settler: intent.settler,
  expiry: BigInt(intent.expiry),
};

// Sign
const signature = await stealthAccount.signTypedData({
  domain: intent.domain,
  types: sigTypes,
  primaryType: 'Intent',
  message,
});

// Attach signature to the intent for submission
intent.signature = signature;
```

#### C. Sign Delegations (EIP-7702)

Delegations authorize the stealth address to use a smart account implementation. They use EIP-7702 authorization format, signed by the same stealth private key:

```javascript
// For each delegation in quote.delegations:
const stealthAccount = /* same stealth account used for the corresponding intent */;

const authorization = await stealthAccount.signAuthorization({
  contractAddress: delegation.contractAddress,
  chainId: delegation.chainId,
  nonce: delegation.authorizationNonce,
});

// Combine r + s + v into a single hex signature
const r = authorization.r;
const s = authorization.s;
const v = authorization.v;
const signature = r + s.slice(2) + (v === 27n || v === 27 ? '1b' : '1c');

delegation.signature = signature;
```

### D. Submit

```javascript
const jsonBody = JSON.stringify({
  quoteId: quote.quoteId,
  intents: signedIntents,
  delegations: signedDelegations,
}, (_, v) => typeof v === 'bigint' ? v.toString() : v);

const res = await fetch(`${BASE_URL}/v1/accounts/${ACCOUNT_ID}/submit`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${API_KEY}`,
    'Content-Type': 'application/json',
    'Idempotency-Key': crypto.randomUUID(),
  },
  body: jsonBody,
});
```

## Complete Example

A minimal end-to-end send flow:

```javascript
import { privateKeyToAccount } from 'viem/accounts';
import { decodeAbiParameters, parseAbiParameters, hexToBytes } from 'viem';
import { HDKey } from '@scure/bip32';
import crypto from 'crypto';
import { deriveDeterministicEphemeralKey } from '@cloakedxyz/clkd-stealth/dist/shared/deriveDeterministicEphemeralKey.js';
import { genStealthPrivateKey } from '@cloakedxyz/clkd-stealth/dist/client/genStealthPrivateKey.js';

const API_KEY = process.env.CLKD_API_KEY;
const ACCOUNT_ID = process.env.CLKD_ACCOUNT_ID;
const p_spend = process.env.CLKD_P_SPEND;
const child_p_view = process.env.CLKD_CHILD_P_VIEW;
const BASE_URL = 'https://api.clkd.xyz';

const childViewingNode = HDKey.fromMasterSeed(hexToBytes(child_p_view));

// 1. Quote
const quoteRes = await fetch(`${BASE_URL}/v1/accounts/${ACCOUNT_ID}/quote`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${API_KEY}`,
    'Content-Type': 'application/json',
    'Idempotency-Key': crypto.randomUUID(),
  },
  body: JSON.stringify({
    type: 'send',
    chainId: 8453,
    token: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    amount: '1000000',
    decimals: 6,
    destinationAddress: 'alice.clkd.eth',
  }),
});
const quote = await quoteRes.json();

// 2. Sign intents
for (const intent of quote.intents) {
  const derivNonce = BigInt(intent.derivationNonce);
  const { p_derived } = deriveDeterministicEphemeralKey(childViewingNode, derivNonce);
  const P_derived = privateKeyToAccount(p_derived).publicKey;
  const { p_stealth } = genStealthPrivateKey({ p_spend, P_derived });
  const stealthAccount = privateKeyToAccount(p_stealth);

  const { EIP712Domain, ...sigTypes } = intent.types;
  const calls = decodeAbiParameters(
    parseAbiParameters('(address to, uint256 value, bytes data)[]'),
    intent.executionData
  )[0].map(c => ({ to: c.to, value: c.value, data: c.data }));

  intent.signature = await stealthAccount.signTypedData({
    domain: intent.domain,
    types: sigTypes,
    primaryType: 'Intent',
    message: {
      multichain: intent.isMultichain,
      eoa: intent.eoa,
      calls,
      nonce: BigInt(intent.nonce),
      payer: intent.payer,
      paymentToken: intent.paymentToken,
      paymentMaxAmount: BigInt(intent.paymentMaxAmount),
      combinedGas: BigInt(intent.combinedGas),
      encodedPreCalls: intent.encodedPreCalls,
      encodedFundTransfers: intent.encodedFundTransfers,
      settler: intent.settler,
      expiry: BigInt(intent.expiry),
    },
  });

  // Sign delegation with the same stealth key
  for (const deleg of quote.delegations) {
    const auth = await stealthAccount.signAuthorization({
      contractAddress: deleg.contractAddress,
      chainId: deleg.chainId,
      nonce: deleg.authorizationNonce,
    });
    deleg.signature = auth.r + auth.s.slice(2) +
      (auth.v === 27n || auth.v === 27 ? '1b' : '1c');
  }
}

// 3. Submit
const submitRes = await fetch(`${BASE_URL}/v1/accounts/${ACCOUNT_ID}/submit`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${API_KEY}`,
    'Content-Type': 'application/json',
    'Idempotency-Key': crypto.randomUUID(),
  },
  body: JSON.stringify({
    quoteId: quote.quoteId,
    intents: quote.intents,
    delegations: quote.delegations,
  }, (_, v) => typeof v === 'bigint' ? v.toString() : v),
});

console.log(await submitRes.json());
// { success: true, quoteId: "...", status: "queued", message: "Transaction queued for relay" }
```
