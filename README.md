<p align="center">
  <img src="docs/logo.png" alt="Cerbero Logo" width="180" />
</p>

<h1 align="center">Cerbero</h1>

<p align="center">
  <em>Guardian of the gates — no one enters without passing through him.</em>
</p>

<p align="center">
  <img alt="Delphi 12" src="https://img.shields.io/badge/Delphi-12%20Athens-red?style=flat-square" />
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" />
  <img alt="No Dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square" />
</p>

---

Cerbero is a **JWT authentication library for Delphi** — zero external dependencies, fluent builder API, and a clean exception model. Inspired by Devise (Ruby), ASP.NET Core Authentication, and Passport (Node.js).

Part of the **Olympian Family** of Delphi frameworks:

| Library | Role |
|---------|------|
| [Poseidon](https://github.com/herlondf/poseidon) | Transport layer |
| [Pegasus](https://github.com/herlondf/pegasus) | HTTP framework |
| [Triton](https://github.com/herlondf/triton) | Object pool |
| [Hermes](https://github.com/herlondf/hermes) | Redis client |
| **Cerbero** | Auth / JWT |

---

## Requirements

- RAD Studio 12 Athens (or later)
- No external packages — uses only Delphi RTL (`System.Hash`, `System.JSON`, `System.NetEncoding`)

---

## Installation

Copy the `src/` directory into your project, or add it to your library search path in RAD Studio:

1. Open **Tools > Options > Language > Delphi > Library**.
2. Add the full path to `<cerbero>/src/` to **Library path**.
3. Add `Cerbero` to the `uses` clause of any unit that needs it.

---

## Quick Start

### Generate a token

```delphi
uses Cerbero;

var
  LToken: string;
begin
  LToken := TCerbero.Token
    .Subject('user-123')
    .Issuer('myapp')
    .Audience('api')
    .Claim('role', 'admin')
    .ClaimInt('level', 5)
    .ClaimBool('active', True)
    .NotBefore(0)       // valid immediately
    .ExpiresIn(3600)    // expires in 1 hour
    .SignWith('my-secret');
end;
```

### Verify a token

```delphi
uses Cerbero, Cerbero.Interfaces;

var
  LClaims: ICerberoClaims;
begin
  if TCerbero.Verify(LToken).WithSecret('my-secret').IsValid then
  begin
    LClaims := TCerbero.Decode(LToken, 'my-secret');

    WriteLn(LClaims.Subject);           // 'user-123'
    WriteLn(LClaims.Issuer);            // 'myapp'
    WriteLn(LClaims.Audience);          // 'api'
    WriteLn(LClaims.Get('role'));        // 'admin'
    WriteLn(LClaims.GetInt('level'));    // 5
    WriteLn(LClaims.GetBool('active')); // true
    WriteLn(LClaims.IsExpired);         // false
    WriteLn(LClaims.ExpiresAt);         // unix timestamp
    WriteLn(LClaims.IssuedAt);          // unix timestamp
    WriteLn(LClaims.NotBefore);         // unix timestamp (0 if not set)
  end;
end;
```

### Verify with clock skew tolerance

```delphi
// Accept tokens expired by up to 30 seconds (clock drift between servers)
if TCerbero.Verify(LToken).WithSecret('my-secret').WithLeeway(30).IsValid then
  ...
```

### Decode in one call

```delphi
// Raises ECerberoExpiredToken, ECerberoInvalidSignature, etc. on failure
LClaims := TCerbero.Decode(LToken, 'my-secret');
```

### Renew an expired token

`UnsafeDecode` validates the signature but skips `exp`/`nbf` — use it to read claims from an expired token. `Refresh` wraps this into a one-liner that copies all claims and issues a new token:

```delphi
// Read claims from an expired token (signature still validated)
LClaims := TCerbero.UnsafeDecode(LExpiredToken, 'my-secret');

// Or renew in one call — copies sub, iss, aud, role, and all custom claims
LNewToken := TCerbero.Refresh(LExpiredToken, 'my-secret', 3600);
```

---

## Pegasus Middleware

Add `Cerbero.Middleware.Pegasus` to your search path alongside Pegasus.

### Protect a route (reject if no valid token)

```delphi
uses Cerbero.Middleware.Pegasus;

LApp.Get('/me', TCerberoMiddleware.JWT('my-secret'),
  procedure(Req: TPegasusRequest; Res: TPegasusResponse)
  begin
    Res.Send('{"ok":true}');
  end);
```

### Validate and inject claims into the request

```delphi
LApp.Get('/me',
  TCerberoMiddleware.JWTWithClaims('my-secret',
    procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
    begin
      Req.Params.AddOrSet('jwt_sub',  Claims.Subject);
      Req.Params.AddOrSet('jwt_role', Claims.Get('role'));
    end),
  procedure(Req: TPegasusRequest; Res: TPegasusResponse)
  begin
    Res.Send(Req.Params.GetOrDefault('jwt_sub', ''));
  end);
```

### Optional auth (public route enriched when logged in)

```delphi
// Passes through even without a token; injects claims only when valid token is present
LApp.Get('/feed',
  TCerberoMiddleware.JWTOptional('my-secret',
    procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
    begin
      Req.Params.AddOrSet('jwt_sub', Claims.Subject);
    end),
  procedure(Req: TPegasusRequest; Res: TPegasusResponse)
  begin
    // jwt_sub is set if logged in, empty if anonymous
    Res.Send(Req.Params.GetOrDefault('jwt_sub', 'anonymous'));
  end);
```

All middleware variants expect the token in the `Authorization: Bearer <token>` header.

---

## Exception Reference

| Exception | Raised by | When |
|-----------|-----------|------|
| `ECerberoInvalidToken` | `Claims`, `Decode`, `UnsafeDecode`, `Refresh` | Token is malformed or cannot be parsed |
| `ECerberoInvalidSignature` | `Claims`, `Decode`, `UnsafeDecode`, `Refresh` | HMAC signature does not match |
| `ECerberoExpiredToken` | `Claims`, `Decode` | `exp` claim is in the past (outside leeway) |
| `ECerberoNotYetValidToken` | `Claims`, `Decode` | `nbf` claim is in the future (outside leeway) |
| `ECerberoMissingSecret` | `SignWith`, `IsValid`, `Claims`, `Decode` | Secret is an empty string |

`IsValid` never raises — it returns `False` for all error conditions except `ECerberoMissingSecret`.  
`UnsafeDecode` and `Refresh` skip `exp`/`nbf` checks but still raise signature and format errors.

---

## API Reference

### `TCerbero` — entry point

| Method | Description |
|--------|-------------|
| `Token` | Returns a new fluent token builder (`ICerberoTokenBuilder`) |
| `Verify(token)` | Returns a verifier (`ICerberoVerifier`) — chain `WithSecret` and `IsValid`/`Claims` |
| `Decode(token, secret)` | Validates and returns claims in one call; raises on any failure |
| `UnsafeDecode(token, secret)` | Validates signature only; skips `exp`/`nbf`; raises on bad signature |
| `Refresh(token, secret, ttl)` | Renews a token, copying all non-temporal claims; raises on bad signature |

### `ICerberoTokenBuilder` — fluent builder

| Method | Description |
|--------|-------------|
| `Subject(s)` | Sets `sub` claim |
| `Issuer(s)` | Sets `iss` claim |
| `Audience(s)` | Sets `aud` claim |
| `ExpiresIn(seconds)` | Sets `exp` to `now + seconds` |
| `NotBefore(seconds)` | Sets `nbf` to `now + seconds` (use negative for past) |
| `Claim(name, value)` | Adds a string claim |
| `ClaimInt(name, value)` | Adds an integer claim |
| `ClaimBool(name, value)` | Adds a boolean claim |
| `SignWith(secret)` | Signs the token and returns the JWT string |

Calling the same method twice overwrites the previous value — last call wins.

### `ICerberoVerifier` — verification chain

| Method | Description |
|--------|-------------|
| `WithSecret(secret)` | Sets the HMAC secret |
| `WithLeeway(seconds)` | Adds clock-skew tolerance to `exp` and `nbf` checks |
| `IsValid` | Returns `True` if signature, `exp`, and `nbf` are all valid; never raises |
| `Claims` | Returns `ICerberoClaims`; raises typed exceptions on any failure |
| `UnsafeClaims` | Returns `ICerberoClaims`; validates signature only; skips temporal checks |

### `ICerberoClaims` — decoded payload

| Method | Description |
|--------|-------------|
| `Subject` | Returns `sub` claim |
| `Issuer` | Returns `iss` claim |
| `Audience` | Returns `aud` claim |
| `ExpiresAt` | Returns `exp` as Unix timestamp (0 if not set) |
| `IssuedAt` | Returns `iat` as Unix timestamp |
| `NotBefore` | Returns `nbf` as Unix timestamp (0 if not set) |
| `IsExpired` | `True` if `exp` is set and in the past |
| `IsNotYetValid` | `True` if `nbf` is set and in the future |
| `Get(name)` | Returns a string claim value |
| `GetInt(name)` | Returns an integer claim value |
| `GetBool(name)` | Returns a boolean claim value |
| `Has(name)` | `True` if the claim exists in the payload |
| `CopyTo(builder)` | Copies all non-temporal claims to a builder (preserves types) |

---

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) (English) or [docs/CONTRIBUTING_pt-br.md](docs/CONTRIBUTING_pt-br.md) (Portuguese).

---

## License

MIT © Olympian Family contributors.

---

> 🇧🇷 Leia este documento em português: [README_pt-br.md](./README_pt-br.md)
