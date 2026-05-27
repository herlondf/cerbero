<p align="center">
  <img src="docs/logo.png" alt="Cerbero Logo" width="180" />
</p>

<h1 align="center">Cerbero</h1>

<p align="center">
  <em>Guardian of the gates — no one enters without passing through him.</em>
</p>

<p align="center">
  <!-- badges placeholder -->
  <img alt="Delphi 12" src="https://img.shields.io/badge/Delphi-12%20Athens-red?style=flat-square" />
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" />
  <img alt="No Dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square" />
</p>

---

Cerbero is a **JWT authentication library for Delphi** — zero external dependencies, fluent API, and a clean exception model. Inspired by Devise (Ruby), ASP.NET Core Authentication, and Passport (Node.js).

Part of the **Olympian Family** of Delphi frameworks:

| Library | Role |
|---------|------|
| [Poseidon](https://github.com/your-org/poseidon) | Transport layer |
| [Pegasus](https://github.com/your-org/pegasus) | HTTP framework |
| [Triton](https://github.com/your-org/triton) | Object pool |
| [Hermes](https://github.com/your-org/hermes) | Redis client |
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
    .ExpiresIn(3600)
    .SignWith('my-secret');
end;
```

### Verify a token

```delphi
uses Cerbero;

var
  LVerifier: ICerberoVerifyResult;
  LClaims: ICerberoClaims;
begin
  LVerifier := TCerbero.Verify(LToken).WithSecret('my-secret');

  if LVerifier.IsValid then
  begin
    LClaims := LVerifier.Claims;

    Writeln(LClaims.Subject);          // 'user-123'
    Writeln(LClaims.Issuer);           // 'myapp'
    Writeln(LClaims.Audience);         // 'api'
    Writeln(LClaims.Get('role'));       // 'admin'
    Writeln(LClaims.GetInt('level'));   // 5
    Writeln(LClaims.GetBool('active')); // true
    Writeln(LClaims.IsExpired);        // false
    Writeln(LClaims.ExpiresAt);        // unix timestamp
    Writeln(LClaims.IssuedAt);         // unix timestamp
  end;
end;
```

---

## Exceptions

| Exception | When raised |
|-----------|-------------|
| `ECerberoInvalidToken` | Token is malformed or cannot be parsed |
| `ECerberoExpiredToken` | Token `exp` claim is in the past |
| `ECerberoInvalidSignature` | HMAC signature does not match |
| `ECerberoMissingSecret` | `SignWith` or `WithSecret` called with empty string |

---

## Roadmap

- [x] HS256 JWT generation and verification
- [x] Standard claims (`sub`, `iss`, `aud`, `exp`, `iat`)
- [x] Custom claims (string, integer, boolean)
- [ ] API Keys (planned — integration with Iris)
- [ ] OAuth2 flows (planned — integration with Iris)

---

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) (English) or [docs/CONTRIBUTING_pt-br.md](docs/CONTRIBUTING_pt-br.md) (Portuguese).

---

## License

MIT © Olympian Family contributors.

---

> 🇧🇷 Leia este documento em português: [README_pt-br.md](./README_pt-br.md)
