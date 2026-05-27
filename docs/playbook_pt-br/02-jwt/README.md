# 02 — Internos do JWT e a API do Cerbero

## Estrutura de um JWT

Um JSON Web Token é formado por três segmentos codificados em Base64URL separados por pontos:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9   ← header
.
eyJzdWIiOiJ1c2VyLTEyMyIsInJvbGUiOiJhZG1pbiIsImV4cCI6MTcwMDAwMDAwMH0   ← payload
.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c   ← assinatura
```

### Header

```json
{ "alg": "HS256", "typ": "JWT" }
```

O Cerbero sempre produz `alg: HS256`. O header é codificado em Base64URL e incluído na mensagem assinada.

### Payload

O payload é um objeto JSON que carrega **claims** — pares chave/valor sobre o sujeito. As claims padrão (registradas) têm nomes curtos definidos pelo [RFC 7519](https://tools.ietf.org/html/rfc7519):

| Claim | Nome | Tipo | Descrição |
|-------|------|------|-----------|
| `sub` | Subject | string | Quem o token representa |
| `iss` | Issuer | string | Quem emitiu o token |
| `aud` | Audience | string | Destinatário pretendido |
| `exp` | Expiration | Unix timestamp | Após esse momento o token é inválido |
| `nbf` | Not Before | Unix timestamp | Antes desse momento o token é inválido |
| `iat` | Issued At | Unix timestamp | Quando o token foi emitido (definido automaticamente) |

O Cerbero também suporta **claims customizadas** dos tipos string, inteiro e booleano.

### Assinatura

```
HMAC-SHA256(
  base64url(header) + "." + base64url(payload),
  secret
)
```

A assinatura é calculada sobre os bytes exatos do header e payload codificados. Alterar um único caractere em qualquer das seções invalida a assinatura — é isso que `ECerberoInvalidSignature` detecta.

---

## Como o Cerbero Implementa o JWT

### Codificação Base64URL

O Base64 padrão usa os caracteres `+`, `/` e `=`, que não são seguros em URLs. O Cerbero converte usando `TNetEncoding.Base64` e aplica três substituições:

```pascal
Result := Result.Replace('+', '-', [rfReplaceAll]);
Result := Result.Replace('/', '_', [rfReplaceAll]);
Result := Result.Replace('=', '',  [rfReplaceAll]);
```

A decodificação inverte o processo, recolocando o padding `=` necessário antes de chamar o decodificador Base64.

### HMAC-SHA256

```pascal
THashSHA2.GetHMACAsBytes(
  TEncoding.UTF8.GetBytes(message),
  TEncoding.UTF8.GetBytes(secret),
  THashSHA2.TSHA2Version.SHA256
)
```

Tanto a mensagem quanto o secret são convertidos para bytes UTF-8 antes do hash. Isso corresponde ao comportamento de bibliotecas JWT padrão em outras linguagens.

### Unix timestamps

```pascal
DateTimeToUnix(Now, False)
```

O segundo argumento (`False`) exclui o offset de fuso horário local do cálculo, produzindo um Unix timestamp UTC puro.

---

## Geração de Tokens

### Token básico

```delphi
LToken := TCerbero.Token
  .Subject('user-123')
  .Issuer('myapp')
  .ExpiresIn(3600)
  .SignWith('my-secret');
```

`iat` é adicionado automaticamente quando `SignWith` é chamado — você não precisa defini-lo.

### Todas as claims padrão

```delphi
LToken := TCerbero.Token
  .Subject('user-123')
  .Issuer('myapp')
  .Audience('api-v2')
  .ExpiresIn(3600)          // exp = agora + 3600
  .NotBefore(-5)            // nbf = agora - 5  (válido desde 5 segundos atrás)
  .SignWith('my-secret');
```

### Claims customizadas

```delphi
LToken := TCerbero.Token
  .Subject('user-123')
  .Claim('role', 'admin')         // string
  .ClaimInt('tenant_id', 42)      // inteiro
  .ClaimBool('verified', True)    // booleano
  .ExpiresIn(3600)
  .SignWith('my-secret');
```

### Claims duplicadas

Chamar o mesmo método duas vezes sobrescreve o valor anterior — vence a última chamada. Isso é seguro porque `SetPair` remove o par existente antes de adicionar o novo:

```delphi
TCerbero.Token.Subject('primeiro').Subject('segundo').SignWith(s);
// sub = 'segundo'

TCerbero.Token.ExpiresIn(-1).ExpiresIn(3600).SignWith(s);
// exp = agora + 3600  (não expirado)
```

---

## Verificação de Tokens

### Caminho booleano — `IsValid`

```delphi
if TCerbero.Verify(LToken).WithSecret('my-secret').IsValid then
  // token válido
```

`IsValid` retorna `False` para: token malformado, assinatura errada, token expirado, token ainda não válido. Lança apenas `ECerberoMissingSecret` quando o secret está vazio.

### Caminho por exceção — `Claims` / `Decode`

```delphi
try
  LClaims := TCerbero.Decode(LToken, 'my-secret');
  // usar LClaims
except
  on E: ECerberoExpiredToken     do { tratar expirado };
  on E: ECerberoInvalidSignature do { tratar adulterado };
  on E: ECerberoInvalidToken     do { tratar malformado };
end;
```

### Tolerância de clock skew — `WithLeeway`

Em sistemas distribuídos, os relógios dos servidores derivam. `WithLeeway(segundos)` expande a janela de validade:

- Verificação de `exp`: `agora <= exp + leeway`
- Verificação de `nbf`: `agora >= nbf - leeway`

```delphi
// Aceita tokens expirados há até 30 segundos
TCerbero.Verify(LToken).WithSecret('secret').WithLeeway(30).IsValid;
```

Um leeway de 30 a 60 segundos é típico para sistemas em produção.

---

## Fluxo de Renovação de Token

Quando um token expira, o cliente precisa de um novo sem forçar o usuário a se autenticar novamente. O padrão usando o Cerbero:

```delphi
// Cliente envia o token expirado para POST /auth/refresh

// 1. Lê claims do token expirado (assinatura ainda é validada)
LClaims := TCerbero.UnsafeDecode(LExpiredToken, SECRET);

// 2. Opcionalmente inspeciona o subject e aplica regras de negócio
//    (ex: verificar se o usuário ainda está ativo no banco de dados)
if not IsUserActive(LClaims.Subject) then
begin
  Res.Status(401).Send('{"error":"user_inactive"}');
  Exit;
end;

// 3. Emite novo token — copia todas as claims não-temporais automaticamente
LNewToken := TCerbero.Refresh(LExpiredToken, SECRET, 3600);
Res.Send('{"token":"' + LNewToken + '"}');
```

`Refresh` copia `sub`, `iss`, `aud` e todas as claims customizadas, descartando `exp`, `nbf` e `iat` — esses são recalculados para o novo token.

---

## Middleware Pegasus

`Cerbero.Middleware.Pegasus` oferece três fábricas de callback para o framework HTTP Pegasus.

### `JWT` — autenticação obrigatória

Rejeita com HTTP 401 se o header `Authorization: Bearer <token>` estiver ausente ou contiver um token inválido.

```delphi
LApp.Get('/protegido', TCerberoMiddleware.JWT('secret'), handler);
```

### `JWTWithClaims` — autenticação obrigatória + injeção de claims

Igual ao `JWT`, mas após uma validação bem-sucedida chama um procedimento injector com as claims decodificadas antes de invocar `Next`. Use para popular `Req.Params` com valores das claims.

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

### `JWTOptional` — autenticação opcional

Sempre chama `Next`. Se um Bearer token válido estiver presente, o injector é chamado primeiro. Se o token estiver ausente ou inválido, o injector é silenciosamente ignorado. Use para rotas públicas que podem opcionalmente servir conteúdo personalizado.

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

## Notas de Segurança

1. **Força do secret** — use pelo menos 32 bytes aleatórios para o secret. Um secret curto ou previsível permite ataques de força bruta offline contra tokens capturados.
2. **Somente HTTPS** — um JWT transmitido por HTTP simples pode ser roubado e replicado. Use sempre TLS em produção.
3. **Validade curta** — prefira `ExpiresIn(900)` (15 minutos) a tokens de várias horas, combinado com um fluxo de renovação.
4. **Respostas JSON** — sempre serialize JSON com `TJSONObject`, nunca por concatenação de strings. Um valor de claim contendo `"` ou `}` quebraria um JSON montado manualmente.

---

> Anterior: [01 — Visão Geral](../01-visao-geral/)
>
> 🇺🇸 Read in English: [02-jwt](../../playbook/02-jwt/)
