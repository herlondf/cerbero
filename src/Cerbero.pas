unit Cerbero;

interface

uses
  Cerbero.Interfaces,
  Cerbero.JWT;

type
  TCerbero = class
  public
    /// Inicia a construcao de um JWT com a API fluente.
    /// Exemplo:
    ///   LToken := TCerbero.Token
    ///     .Subject('user-123')
    ///     .Claim('role', 'admin')
    ///     .ExpiresIn(3600)
    ///     .SignWith('secret');
    class function Token: ICerberoTokenBuilder; static;

    /// Inicia a verificacao de um JWT.
    /// Exemplo:
    ///   if TCerbero.Verify(LToken).WithSecret('secret').IsValid then
    ///     LClaims := TCerbero.Verify(LToken).WithSecret('secret').Claims;
    class function Verify(const AToken: string): ICerberoVerifier; static;

    /// Verifica e retorna os claims em uma unica chamada.
    /// Lanca ECerberoInvalidSignature se a assinatura for invalida,
    /// ECerberoInvalidToken se o token for malformado,
    /// ECerberoMissingSecret se ASecret estiver vazio.
    /// Exemplo:
    ///   LClaims := TCerbero.Decode(LToken, 'secret');
    ///   WriteLn(LClaims.Subject);
    class function Decode(const AToken, ASecret: string): ICerberoClaims; static;

    /// Valida apenas a assinatura e retorna os claims sem verificar exp/nbf.
    /// Util para renovacao de tokens: le o subject de um token expirado sem lancar
    /// ECerberoExpiredToken. Ainda lanca ECerberoInvalidSignature/Token/MissingSecret.
    /// Exemplo:
    ///   LClaims := TCerbero.UnsafeDecode(LExpiredToken, 'secret');
    ///   LNewToken := TCerbero.Token.Subject(LClaims.Subject).ExpiresIn(3600).SignWith('secret');
    class function UnsafeDecode(const AToken, ASecret: string): ICerberoClaims; static;

    /// Renova um token expirado ou proximo de expirar sem exigir re-autenticacao.
    /// Copia todas as claims registradas (sub, iss, aud, role, etc.) e emite novo
    /// token com ANewTTL segundos de validade. Nao copia exp/nbf/iat do original.
    /// Lanca ECerberoInvalidSignature se a assinatura for invalida.
    /// Exemplo:
    ///   LNewToken := TCerbero.Refresh(LExpiredToken, 'secret', 3600);
    class function Refresh(const AToken, ASecret: string; ANewTTL: Integer): string; static;
  end;

implementation

class function TCerbero.Token: ICerberoTokenBuilder;
begin
  Result := TCerberoJWTBuilder.Create;
end;

class function TCerbero.Verify(const AToken: string): ICerberoVerifier;
begin
  Result := TCerberoJWTVerifier.Create(AToken);
end;

class function TCerbero.Decode(const AToken, ASecret: string): ICerberoClaims;
begin
  Result := TCerberoJWTVerifier.Create(AToken).WithSecret(ASecret).Claims;
end;

class function TCerbero.UnsafeDecode(const AToken, ASecret: string): ICerberoClaims;
begin
  Result := TCerberoJWTVerifier.Create(AToken).WithSecret(ASecret).UnsafeClaims;
end;

class function TCerbero.Refresh(const AToken, ASecret: string; ANewTTL: Integer): string;
var
  LClaims: ICerberoClaims;
  LBuilder: ICerberoTokenBuilder;
begin
  LClaims  := UnsafeDecode(AToken, ASecret);
  LBuilder := Token;
  LClaims.CopyTo(LBuilder);
  LBuilder.ExpiresIn(ANewTTL);
  Result := LBuilder.SignWith(ASecret);
end;

end.
