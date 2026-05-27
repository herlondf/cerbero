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

end.
