# 01 — Overview

## What is Cerbero?

Cerbero is a **JWT (JSON Web Token) authentication library for Delphi**. It handles token generation, cryptographic signing, verification, and claim extraction — the complete authentication primitive for HTTP APIs.

The name comes from the three-headed dog of Greek mythology who guards the gates of the underworld. In the same spirit, Cerbero guards the gates of your application: no request passes without first being challenged.

---

## Design Goals

### Zero external dependencies

Cerbero relies exclusively on the Delphi RTL:

| RTL unit | Used for |
|----------|----------|
| `System.Hash` | HMAC-SHA256 via `THashSHA2.GetHMACAsBytes` |
| `System.JSON` | JSON serialisation/deserialisation of header and payload |
| `System.NetEncoding` | Base64 encoding, then manually converted to Base64URL |
| `System.DateUtils` | `DateTimeToUnix` for `iat`, `exp`, `nbf` timestamps |

No OpenSSL, no third-party crypto, no NuGet-style packages. A single search path entry is enough.

### Fluent, chainable API

Token creation and verification are designed to read like a sentence:

```delphi
TCerbero.Token
  .Subject('user-123')
  .Claim('role', 'admin')
  .ExpiresIn(3600)
  .SignWith('secret');

TCerbero.Verify(token).WithSecret('secret').WithLeeway(30).IsValid;
```

### Typed exception model

Every failure mode has its own exception class, all derived from `ECerberoException`:

```
ECerberoException
├── ECerberoInvalidToken       — malformed JWT structure
├── ECerberoInvalidSignature   — HMAC mismatch
├── ECerberoExpiredToken       — exp in the past
├── ECerberoNotYetValidToken   — nbf in the future
└── ECerberoMissingSecret      — empty secret string
```

Callers decide which failures to handle and which to let propagate. `IsValid` provides a safe boolean path when exceptions are unwanted.

### Clear separation between "safe" and "unsafe" operations

| Method | Validates signature | Validates exp/nbf |
|--------|--------------------|--------------------|
| `Claims` / `Decode` | Yes | Yes |
| `UnsafeClaims` / `UnsafeDecode` | Yes | No |
| `IsValid` | Yes | Yes |
| `Refresh` | Yes (via UnsafeDecode) | No |

This distinction matters for **token refresh flows**: you must read the subject from an expired token to issue a new one. `UnsafeDecode` makes this safe — the signature is always enforced.

---

## What Cerbero is NOT

- **Not an OAuth2 server.** Cerbero does not implement authorization code flows, client credentials, or token introspection endpoints. It only handles JWT issuance and validation.
- **Not an asymmetric signing library.** Only HMAC-SHA256 (HS256) is supported. RS256/ES256 would require a crypto dependency, which conflicts with the zero-dependency goal.
- **Not a session manager.** There is no token storage, revocation list, or blacklist mechanism. Stateless verification only.
- **Not a user database.** Cerbero has no concept of users, passwords, or roles beyond what you put in claims.

---

## How Cerbero fits in the Olympian Family

```
HTTP Request
     │
     ▼
 [Pegasus]  ←── HTTP framework (routing, middleware chain)
     │
     ▼
 [Cerbero]  ←── JWT validation middleware
     │
     ▼
 Route handler
     │
     ▼
 [Hermes]   ←── Redis (sessions, rate limiting, caching)
```

Cerbero integrates with Pegasus via `TCerberoMiddleware` in `Cerbero.Middleware.Pegasus`. The middleware sits in the Pegasus callback chain and calls `Next` only when the token is valid.

---

## File structure

```
src/
├── Cerbero.pas                    ← entry point: TCerbero class
├── Cerbero.Interfaces.pas         ← ICerberoTokenBuilder, ICerberoVerifier, ICerberoClaims
├── Cerbero.Core.Types.pas         ← exception hierarchy + JWT constants
├── Cerbero.JWT.pas                ← implementation: builder, verifier, claims
└── Cerbero.Middleware.Pegasus.pas ← Pegasus middleware (optional, requires Pegasus)
```

The only file that requires Pegasus is `Cerbero.Middleware.Pegasus`. The rest of the library has no framework dependency.

---

> Next: [02 — JWT internals and the Cerbero API](../02-jwt/)
>
> 🇧🇷 Leia em português: [01-visao-geral](../../playbook_pt-br/01-visao-geral/)
