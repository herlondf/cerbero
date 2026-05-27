program Cerbero.Sample.JWTBasic;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Cerbero in '..\..\src\Cerbero.pas',
  Cerbero.Interfaces in '..\..\src\Cerbero.Interfaces.pas',
  Cerbero.Core.Types in '..\..\src\Cerbero.Core.Types.pas',
  Cerbero.JWT in '..\..\src\Cerbero.JWT.pas';

const
  SECRET = 'my-super-secret-key';

var
  LToken  : string;
  LClaims : ICerberoClaims;
  LVerifier: ICerberoVerifier;

begin
  WriteLn('=== Cerbero — JWT Basic Sample ===');
  WriteLn;

  // 1. Gerar token
  LToken := TCerbero.Token
    .Subject('user-123')
    .Issuer('myapp')
    .Audience('api')
    .Claim('role', 'admin')
    .ClaimInt('level', 5)
    .ClaimBool('active', True)
    .ExpiresIn(3600)
    .SignWith(SECRET);

  WriteLn('Token gerado:');
  WriteLn(LToken);
  WriteLn;

  // 2. Verificar assinatura
  LVerifier := TCerbero.Verify(LToken).WithSecret(SECRET);
  WriteLn('Token valido: ', LVerifier.IsValid);
  WriteLn('Token com secret errado: ',
    TCerbero.Verify(LToken).WithSecret('wrong').IsValid);
  WriteLn;

  // 3. Ler claims
  LClaims := TCerbero.Verify(LToken).WithSecret(SECRET).Claims;
  WriteLn('Subject : ', LClaims.Subject);
  WriteLn('Issuer  : ', LClaims.Issuer);
  WriteLn('Audience: ', LClaims.Audience);
  WriteLn('Role    : ', LClaims.Get('role'));
  WriteLn('Level   : ', LClaims.GetInt('level'));
  WriteLn('Active  : ', LClaims.GetBool('active'));
  WriteLn('Expirado: ', LClaims.IsExpired);
  WriteLn('Exp (unix): ', LClaims.ExpiresAt);
  WriteLn('Iat (unix): ', LClaims.IssuedAt);

  ReadLn;
end.
