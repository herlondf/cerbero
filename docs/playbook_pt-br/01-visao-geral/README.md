# 01 — Visão Geral

## O que é o Cerbero?

Cerbero é uma **biblioteca de autenticação JWT (JSON Web Token) para Delphi**. Ela cuida da geração de tokens, assinatura criptográfica, verificação e extração de claims — o primitivo completo de autenticação para APIs HTTP.

O nome vem do cão de três cabeças da mitologia grega que guarda os portões do submundo. No mesmo espírito, o Cerbero guarda os portões da sua aplicação: nenhuma requisição passa sem antes ser desafiada.

---

## Objetivos de Design

### Zero dependências externas

O Cerbero depende exclusivamente da RTL do Delphi:

| Unit da RTL | Utilizada para |
|-------------|---------------|
| `System.Hash` | HMAC-SHA256 via `THashSHA2.GetHMACAsBytes` |
| `System.JSON` | Serialização/deserialização JSON do header e payload |
| `System.NetEncoding` | Codificação Base64, convertida manualmente para Base64URL |
| `System.DateUtils` | `DateTimeToUnix` para os timestamps `iat`, `exp`, `nbf` |

Sem OpenSSL, sem crypto de terceiros, sem pacotes externos. Basta uma entrada no search path.

### API fluente e encadeável

Criação e verificação de tokens foram projetados para se ler como uma frase:

```delphi
TCerbero.Token
  .Subject('user-123')
  .Claim('role', 'admin')
  .ExpiresIn(3600)
  .SignWith('secret');

TCerbero.Verify(token).WithSecret('secret').WithLeeway(30).IsValid;
```

### Modelo de exceções tipado

Cada modo de falha tem sua própria classe de exceção, todas derivadas de `ECerberoException`:

```
ECerberoException
├── ECerberoInvalidToken       — estrutura JWT malformada
├── ECerberoInvalidSignature   — HMAC não confere
├── ECerberoExpiredToken       — exp está no passado
├── ECerberoNotYetValidToken   — nbf está no futuro
└── ECerberoMissingSecret      — secret é string vazia
```

O chamador decide quais falhas tratar e quais deixar propagar. `IsValid` oferece um caminho booleano seguro quando exceções são indesejadas.

### Separação clara entre operações "seguras" e "não seguras"

| Método | Valida assinatura | Valida exp/nbf |
|--------|------------------|----------------|
| `Claims` / `Decode` | Sim | Sim |
| `UnsafeClaims` / `UnsafeDecode` | Sim | Não |
| `IsValid` | Sim | Sim |
| `Refresh` | Sim (via UnsafeDecode) | Não |

Essa distinção é importante para **fluxos de renovação de tokens**: para emitir um novo token, você precisa ler o subject de um token expirado. `UnsafeDecode` torna isso seguro — a assinatura é sempre validada.

---

## O que o Cerbero NÃO é

- **Não é um servidor OAuth2.** O Cerbero não implementa fluxos de authorization code, client credentials nem endpoints de token introspection. Ele apenas cuida da emissão e validação de JWT.
- **Não é uma biblioteca de assinatura assimétrica.** Apenas HMAC-SHA256 (HS256) é suportado. RS256/ES256 exigiriam uma dependência de crypto, o que conflita com o objetivo de zero dependências.
- **Não é um gerenciador de sessões.** Não há armazenamento de tokens, lista de revogação ou blacklist. Apenas verificação stateless.
- **Não é um banco de dados de usuários.** O Cerbero não tem conceito de usuários, senhas ou papéis além do que você coloca nas claims.

---

## Como o Cerbero se encaixa na Família Olímpica

```
Requisição HTTP
       │
       ▼
  [Pegasus]  ←── Framework HTTP (roteamento, cadeia de middleware)
       │
       ▼
  [Cerbero]  ←── Middleware de validação JWT
       │
       ▼
  Handler da rota
       │
       ▼
  [Hermes]   ←── Redis (sessões, rate limiting, cache)
```

O Cerbero integra com o Pegasus via `TCerberoMiddleware` em `Cerbero.Middleware.Pegasus`. O middleware fica na cadeia de callbacks do Pegasus e chama `Next` somente quando o token é válido.

---

## Estrutura de arquivos

```
src/
├── Cerbero.pas                    ← ponto de entrada: classe TCerbero
├── Cerbero.Interfaces.pas         ← ICerberoTokenBuilder, ICerberoVerifier, ICerberoClaims
├── Cerbero.Core.Types.pas         ← hierarquia de exceções + constantes JWT
├── Cerbero.JWT.pas                ← implementação: builder, verifier, claims
└── Cerbero.Middleware.Pegasus.pas ← middleware Pegasus (opcional, requer Pegasus)
```

O único arquivo que depende do Pegasus é `Cerbero.Middleware.Pegasus`. O restante da biblioteca não tem dependência de framework.

---

> Próximo: [02 — Internos do JWT e a API do Cerbero](../02-jwt/)
>
> 🇺🇸 Read in English: [01-overview](../../playbook/01-overview/)
