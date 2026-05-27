<p align="center">
  <img src="docs/logo.png" alt="Logo do Cerbero" width="180" />
</p>

<h1 align="center">Cerbero</h1>

<p align="center">
  <em>Guardião das portas — ninguém entra sem passar por ele.</em>
</p>

<p align="center">
  <!-- badges placeholder -->
  <img alt="Delphi 12" src="https://img.shields.io/badge/Delphi-12%20Athens-red?style=flat-square" />
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" />
  <img alt="No Dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square" />
</p>

---

Cerbero é uma **biblioteca de autenticação JWT para Delphi** — sem dependências externas, API fluente e modelo de exceções limpo. Inspirada pelo Devise (Ruby), ASP.NET Core Authentication e Passport (Node.js).

Faz parte da **Família Olímpica** de frameworks Delphi:

| Biblioteca | Função |
|------------|--------|
| [Poseidon](https://github.com/your-org/poseidon) | Camada de transporte |
| [Pegasus](https://github.com/your-org/pegasus) | Framework HTTP |
| [Triton](https://github.com/your-org/triton) | Pool de objetos |
| [Hermes](https://github.com/your-org/hermes) | Cliente Redis |
| **Cerbero** | Auth / JWT |

---

## Requisitos

- RAD Studio 12 Athens (ou superior)
- Sem pacotes externos — utiliza apenas a RTL do Delphi (`System.Hash`, `System.JSON`, `System.NetEncoding`)

---

## Instalação

Copie o diretório `src/` para o seu projeto ou adicione-o ao search path de bibliotecas no RAD Studio:

1. Abra **Tools > Options > Language > Delphi > Library**.
2. Adicione o caminho completo de `<cerbero>/src/` em **Library path**.
3. Acrescente `Cerbero` ao `uses` de qualquer unit que precisar usá-lo.

---

## Início Rápido

### Gerar um token

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

### Verificar um token

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

    Writeln(LClaims.Subject);           // 'user-123'
    Writeln(LClaims.Issuer);            // 'myapp'
    Writeln(LClaims.Audience);          // 'api'
    Writeln(LClaims.Get('role'));        // 'admin'
    Writeln(LClaims.GetInt('level'));    // 5
    Writeln(LClaims.GetBool('active')); // true
    Writeln(LClaims.IsExpired);         // false
    Writeln(LClaims.ExpiresAt);         // unix timestamp
    Writeln(LClaims.IssuedAt);          // unix timestamp
  end;
end;
```

---

## Exceções

| Exceção | Quando é lançada |
|---------|-----------------|
| `ECerberoInvalidToken` | O token está malformado ou não pode ser interpretado |
| `ECerberoExpiredToken` | A claim `exp` do token está no passado |
| `ECerberoInvalidSignature` | A assinatura HMAC não confere |
| `ECerberoMissingSecret` | `SignWith` ou `WithSecret` chamados com string vazia |

---

## Roadmap

- [x] Geração e verificação de JWT com HS256
- [x] Claims padrão (`sub`, `iss`, `aud`, `exp`, `iat`)
- [x] Claims customizadas (string, inteiro, booleano)
- [ ] API Keys (planejado — integração com Iris)
- [ ] Fluxos OAuth2 (planejado — integração com Iris)

---

## Contribuindo

Consulte [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) (inglês) ou [docs/CONTRIBUTING_pt-br.md](docs/CONTRIBUTING_pt-br.md) (português).

---

## Licença

MIT © Contribuidores da Família Olímpica.

---

> 🇺🇸 Read this document in English: [README.md](./README.md)
