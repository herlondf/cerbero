# 02 — JWT Internals and the Cerbero API

## JWT Structure

A JSON Web Token is three Base64URL-encoded segments separated by dots:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9   ← header
.
eyJzdWIiOiJ1c2VyLTEyMyIsInJvbGUiOiJhZG1pbiIsImV4cCI6MTcwMDAwMDAwMH0   ← payload
.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c   ← signature
```

### Header

```json
{ "alg": "HS256", "typ": "JWT" }
```

Cerbero always produces `alg: HS256`. The header is Base64URL-encoded and included in the signed message.

### Payload

The payload is a JSON object carrying **claims** — key/value pairs about the subject. Standard (registered) claims have short names defined by [RFC 7519](https://tools.ietf.org/html/rfc7519):

| Claim | Name | Type | Description |
|-------|------|------|-------------|
| `sub` | Subject | string | Who the token represents |
| `iss` | Issuer | string | Who issued the token |
| `aud` | Audience | string | Intended recipient |
| `exp` | Expiration | Unix timestamp | After this time the token is invalid |
| `nbf` | Not Before | Unix timestamp | Before this time the token is invalid |
| `iat` | Issued At | Unix timestamp | When the token was issued (set automatically) |

Cerbero also supports **custom claims** of type string, integer, and boolean.

### Signature

```
HMAC-SHA256(
  base64url(header) + "." + base64url(payload),
  secret
)
```

The signature is computed over the exact bytes of the encoded header and payload. Changing a single character in either section invalidates the signature — this is what `ECerberoInvalidSignature` detects.

---

## How Cerbero Implements JWT

### Base64URL encoding

Standard Base64 uses `+`, `/`, and `=` characters that are not URL-safe. Cerbero converts using `TNetEncoding.Base64`, then applies three replacements:

```pascal
Result := Result.Replace('+', '-', [rfReplaceAll]);
Result := Result.Replace('/', '_', [rfReplaceAll]);
Result := Result.Replace('=', '',  [rfReplaceAll]);
```

Decoding reverses the process, adding back the required `=` padding before calling the Base64 decoder.

### HMAC-SHA256

```pascal
THashSHA2.GetHMACAsBytes(
  TEncoding.UTF8.GetBytes(message),
  TEncoding.UTF8.GetBytes(secret),
  THashSHA2.TSHA2Version.SHA256
)
```

Both the message and the secret are converted to UTF-8 bytes before hashing. This matches the behaviour of standard JWT libraries in other languages.

### Unix timestamps

```pascal
DateTimeToUnix(Now, False)
```

The second argument (`False`) keeps the local timezone offset out of the calculation, producing a pure UTC Unix timestamp.

---

## Token Generation

### Basic token

```delphi
LToken := TCerbero.Token
  .Subject('user-123')
  .Issuer('myapp')
  .ExpiresIn(3600)
  .SignWith('my-secret');
```

`iat` is added automatically when `SignWith` is called, so you do not need to set it.

### All standard claims

```delphi
LToken := TCerbero.Token
  .Subject('user-123')
  .Issuer('myapp')
  .Audience('api-v2')
  .ExpiresIn(3600)          // exp = now + 3600
  .NotBefore(-5)            // nbf = now - 5  (valid since 5 seconds ago)
  .SignWith('my-secret');
```

### Custom claims

```delphi
LToken := TCerbero.Token
  .Subject('user-123')
  .Claim('role', 'admin')         // string
  .ClaimInt('tenant_id', 42)      // integer
  .ClaimBool('verified', True)    // boolean
  .ExpiresIn(3600)
  .SignWith('my-secret');
```

### Duplicate claims

Calling a builder method twice overwrites the previous value — the last call wins. This is safe because `SetPair` removes any existing pair before adding the new one:

```delphi
TCerbero.Token.Subject('first').Subject('second').SignWith(s);
// sub = 'second'

TCerbero.Token.ExpiresIn(-1).ExpiresIn(3600).SignWith(s);
// exp = now + 3600  (not expired)
```

---

## Token Verification

### Boolean path — `IsValid`

```delphi
if TCerbero.Verify(LToken).WithSecret('my-secret').IsValid then
  // token is valid
```

`IsValid` returns `False` for: malformed token, wrong signature, expired token, not-yet-valid token. It raises only `ECerberoMissingSecret` when the secret is empty.

### Exception path — `Claims` / `Decode`

```delphi
try
  LClaims := TCerbero.Decode(LToken, 'my-secret');
  // use LClaims
except
  on E: ECerberoExpiredToken     do { handle expired };
  on E: ECerberoInvalidSignature do { handle tampered };
  on E: ECerberoInvalidToken     do { handle malformed };
end;
```

### Clock skew tolerance — `WithLeeway`

In distributed systems, server clocks drift. `WithLeeway(seconds)` expands the validity window:

- `exp` check becomes: `now <= exp + leeway`
- `nbf` check becomes: `now >= nbf - leeway`

```delphi
// Accept tokens expired by up to 30 seconds
TCerbero.Verify(LToken).WithSecret('secret').WithLeeway(30).IsValid;
```

A leeway of 30–60 seconds is typical for production systems.

---

## Token Refresh Flow

When a token expires, the client needs a new one without forcing the user to log in again. The pattern using Cerbero:

```delphi
// Client sends the expired token to POST /auth/refresh

// 1. Read claims from the expired token (signature still validated)
LClaims := TCerbero.UnsafeDecode(LExpiredToken, SECRET);

// 2. Optionally inspect the subject and apply business rules
//    (e.g., check if the user is still active in the database)
if not IsUserActive(LClaims.Subject) then
begin
  Res.Status(401).Send('{"error":"user_inactive"}');
  Exit;
end;

// 3. Issue a new token — copies all non-temporal claims automatically
LNewToken := TCerbero.Refresh(LExpiredToken, SECRET, 3600);
Res.Send('{"token":"' + LNewToken + '"}');
```

`Refresh` copies `sub`, `iss`, `aud`, and all custom claims while discarding `exp`, `nbf`, and `iat` — those are recomputed for the new token.

---

## Pegasus Middleware

`Cerbero.Middleware.Pegasus` provides three callback factories for the Pegasus HTTP framework.

### `JWT` — required authentication

Rejects with HTTP 401 if the `Authorization: Bearer <token>` header is absent or contains an invalid token.

```delphi
LApp.Get('/protected', TCerberoMiddleware.JWT('secret'), handler);
```

### `JWTWithClaims` — required authentication + claim injection

Same as `JWT`, but after a successful validation it calls an injector procedure with the decoded claims before invoking `Next`. Use this to populate `Req.Params` with claim values.

```delphi
LApp.Get('/me',
  TCerberoMiddleware.JWTWithClaims('secret',
    procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
    begin
      Req.Params.AddOrSet('user_id', Claims.Subject);
      Req.Params.AddOrSet('role',    Claims.Get('role'));
    end),
  handler);
```

### `JWTOptional` — optional authentication

Always calls `Next`. If a valid Bearer token is present, the injector is called first. If the token is absent or invalid, the injector is silently skipped. Use for public routes that can optionally serve personalised content.

```delphi
LApp.Get('/feed',
  TCerberoMiddleware.JWTOptional('secret',
    procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
    begin
      Req.Params.AddOrSet('user_id', Claims.Subject);
    end),
  handler);
```

---

## Security Notes

1. **Secret strength** — use at least 32 random bytes for the secret. A short or predictable secret allows offline brute-force attacks against captured tokens.
2. **HTTPS only** — a JWT transmitted over plain HTTP can be stolen and replayed. Always use TLS in production.
3. **Short expiry** — prefer `ExpiresIn(900)` (15 minutes) over multi-hour tokens, combined with a refresh flow.
4. **JSON responses** — always serialise JSON with `TJSONObject`, never with string concatenation. A claim value containing `"` or `}` would break a hand-built JSON string.

---

> Previous: [01 — Overview](../01-overview/)
>
> 🇧🇷 Leia em português: [02-jwt](../../playbook_pt-br/02-jwt/)
