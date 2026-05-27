<p align="center">
  <img src="docs/logo.png" alt="Logo do Cerbero" width="180" />
</p>

<h1 align="center">Cerbero</h1>

<p align="center">
  <em>Guardião das portas — ninguém entra sem passar por ele.</em>
</p>

<p align="center">
  <img alt="Delphi 12" src="https://img.shields.io/badge/Delphi-12%20Athens-red?style=flat-square" />
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" />
  <img alt="No Dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square" />
</p>

---

Cerbero é uma **biblioteca de autenticação JWT para Delphi** — sem dependências externas, API fluente com builder encadeado e modelo de exceções limpo. Inspirada pelo Devise (Ruby), ASP.NET Core Authentication e Passport (Node.js).

Faz parte da **Família Olímpica** de frameworks Delphi:

| Biblioteca | Função |
|------------|--------|
| [Poseidon](https://github.com/herlondf/poseidon) | Camada de transporte |
| [Pegasus](https://github.com/herlondf/pegasus) | Framework HTTP |
| [Triton](https://github.com/herlondf/triton) | Pool de objetos |
| [Hermes](https://github.com/herlondf/hermes) | Cliente Redis |
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
    .NotBefore(0)       // válido imediatamente
    .ExpiresIn(3600)    // expira em 1 hora
    .SignWith('my-secret');
end;
```

### Verificar um token

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
    WriteLn(LClaims.NotBefore);         // unix timestamp (0 se não definido)
  end;
end;
```

### Verificar com tolerância de clock skew

```delphi
// Aceita tokens expirados há até 30 segundos (deriva de relógio entre servidores)
if TCerbero.Verify(LToken).WithSecret('my-secret').WithLeeway(30).IsValid then
  ...
```

### Decodificar em uma chamada

```delphi
// Lança ECerberoExpiredToken, ECerberoInvalidSignature, etc. em caso de falha
LClaims := TCerbero.Decode(LToken, 'my-secret');
```

### Renovar um token expirado

`UnsafeDecode` valida a assinatura mas ignora `exp`/`nbf` — use para ler claims de um token expirado. `Refresh` encapsula isso em uma linha, copiando todas as claims e emitindo um novo token:

```delphi
// Lê claims de um token expirado (assinatura ainda é validada)
LClaims := TCerbero.UnsafeDecode(LExpiredToken, 'my-secret');

// Ou renova em uma chamada — copia sub, iss, aud, role e todas as claims customizadas
LNewToken := TCerbero.Refresh(LExpiredToken, 'my-secret', 3600);
```

---

## Middleware Pegasus

Adicione `Cerbero.Middleware.Pegasus` ao search path junto com o Pegasus.

### Proteger uma rota (rejeita se não houver token válido)

```delphi
uses Cerbero.Middleware.Pegasus;

LApp.Get('/me', TCerberoMiddleware.JWT('my-secret'),
  procedure(Req: TPegasusRequest; Res: TPegasusResponse)
  begin
    Res.Send('{"ok":true}');
  end);
```

### Validar e injetar claims no request

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

### Autenticação opcional (rota pública enriquecida quando logado)

```delphi
// Passa adiante mesmo sem token; injeta claims apenas quando o token é válido
LApp.Get('/feed',
  TCerberoMiddleware.JWTOptional('my-secret',
    procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
    begin
      Req.Params.AddOrSet('jwt_sub', Claims.Subject);
    end),
  procedure(Req: TPegasusRequest; Res: TPegasusResponse)
  begin
    // jwt_sub preenchido se logado, vazio se anônimo
    Res.Send(Req.Params.GetOrDefault('jwt_sub', 'anonymous'));
  end);
```

Todos os middlewares esperam o token no header `Authorization: Bearer <token>`.

---

## Referência de Exceções

| Exceção | Lançada por | Quando |
|---------|-------------|--------|
| `ECerberoInvalidToken` | `Claims`, `Decode`, `UnsafeDecode`, `Refresh` | Token malformado ou não pode ser interpretado |
| `ECerberoInvalidSignature` | `Claims`, `Decode`, `UnsafeDecode`, `Refresh` | Assinatura HMAC não confere |
| `ECerberoExpiredToken` | `Claims`, `Decode` | Claim `exp` está no passado (fora do leeway) |
| `ECerberoNotYetValidToken` | `Claims`, `Decode` | Claim `nbf` está no futuro (fora do leeway) |
| `ECerberoMissingSecret` | `SignWith`, `IsValid`, `Claims`, `Decode` | Secret é uma string vazia |

`IsValid` nunca lança exceção — retorna `False` para todas as condições de erro exceto `ECerberoMissingSecret`.  
`UnsafeDecode` e `Refresh` ignoram `exp`/`nbf` mas ainda lançam erros de assinatura e formato.

---

## Referência da API

### `TCerbero` — ponto de entrada

| Método | Descrição |
|--------|-----------|
| `Token` | Retorna um novo builder fluente (`ICerberoTokenBuilder`) |
| `Verify(token)` | Retorna um verificador (`ICerberoVerifier`) — encadeie `WithSecret` e `IsValid`/`Claims` |
| `Decode(token, secret)` | Valida e retorna claims em uma chamada; lança exceção em qualquer falha |
| `UnsafeDecode(token, secret)` | Valida apenas a assinatura; ignora `exp`/`nbf`; lança em assinatura inválida |
| `Refresh(token, secret, ttl)` | Renova um token copiando todas as claims não-temporais; lança em assinatura inválida |

### `ICerberoTokenBuilder` — builder fluente

| Método | Descrição |
|--------|-----------|
| `Subject(s)` | Define a claim `sub` |
| `Issuer(s)` | Define a claim `iss` |
| `Audience(s)` | Define a claim `aud` |
| `ExpiresIn(segundos)` | Define `exp` como `agora + segundos` |
| `NotBefore(segundos)` | Define `nbf` como `agora + segundos` (use negativo para passado) |
| `Claim(nome, valor)` | Adiciona uma claim string |
| `ClaimInt(nome, valor)` | Adiciona uma claim inteira |
| `ClaimBool(nome, valor)` | Adiciona uma claim booleana |
| `SignWith(secret)` | Assina o token e retorna a string JWT |

Chamar o mesmo método duas vezes sobrescreve o valor anterior — vence a última chamada.

### `ICerberoVerifier` — cadeia de verificação

| Método | Descrição |
|--------|-----------|
| `WithSecret(secret)` | Define o secret HMAC |
| `WithLeeway(segundos)` | Adiciona tolerância de clock skew às verificações de `exp` e `nbf` |
| `IsValid` | Retorna `True` se assinatura, `exp` e `nbf` forem válidos; nunca lança exceção |
| `Claims` | Retorna `ICerberoClaims`; lança exceções tipadas em qualquer falha |
| `UnsafeClaims` | Retorna `ICerberoClaims`; valida apenas assinatura; ignora verificações temporais |

### `ICerberoClaims` — payload decodificado

| Método | Descrição |
|--------|-----------|
| `Subject` | Retorna a claim `sub` |
| `Issuer` | Retorna a claim `iss` |
| `Audience` | Retorna a claim `aud` |
| `ExpiresAt` | Retorna `exp` como Unix timestamp (0 se não definido) |
| `IssuedAt` | Retorna `iat` como Unix timestamp |
| `NotBefore` | Retorna `nbf` como Unix timestamp (0 se não definido) |
| `IsExpired` | `True` se `exp` estiver definido e no passado |
| `IsNotYetValid` | `True` se `nbf` estiver definido e no futuro |
| `Get(nome)` | Retorna o valor de uma claim string |
| `GetInt(nome)` | Retorna o valor de uma claim inteira |
| `GetBool(nome)` | Retorna o valor de uma claim booleana |
| `Has(nome)` | `True` se a claim existir no payload |
| `CopyTo(builder)` | Copia todas as claims não-temporais para um builder (preserva tipos) |

---

## Contribuindo

Consulte [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) (inglês) ou [docs/CONTRIBUTING_pt-br.md](docs/CONTRIBUTING_pt-br.md) (português).

---

## Licença

MIT © Contribuidores da Família Olímpica.

---

> 🇺🇸 Read this document in English: [README.md](./README.md)
