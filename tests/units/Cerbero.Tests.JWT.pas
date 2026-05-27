unit Cerbero.Tests.JWT;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Cerbero,
  Cerbero.Interfaces,
  Cerbero.Core.Types;

type
  [TestFixture]
  TCerberoJWTTests = class
  private
    const SECRET = 'test-secret-key-for-cerbero';
  public
    [Test]
    procedure Token_MinimalToken_HasThreeParts;
    [Test]
    procedure Token_WithSubjectAndClaims_ClaimsAreReadBack;
    [Test]
    procedure Token_WithExpiry_IsNotExpiredImmediately;
    [Test]
    procedure Token_WithNegativeExpiry_IsExpired;
    [Test]
    procedure Token_NoExpiry_ExpiresAtIsZeroAndNotExpired;
    [Test]
    procedure Verify_SameSecret_IsValidTrue;
    [Test]
    procedure Verify_WrongSecret_IsValidFalse;
    [Test]
    procedure Verify_TamperedPayload_IsValidFalse;
    [Test]
    procedure Verify_MalformedToken_IsValidFalse;
    [Test]
    procedure Verify_ExpiredToken_IsValidFalse;
    [Test]
    procedure Claims_ValidToken_SubjectAndIssuerMatch;
    [Test]
    procedure Claims_InvalidSignature_RaisesECerberoInvalidSignature;
    [Test]
    procedure Claims_MalformedToken_RaisesECerberoInvalidToken;
    [Test]
    procedure Claims_IntAndBoolRoundTrip;
    [Test]
    procedure Verify_MissingSecret_RaisesECerberoMissingSecret;
    [Test]
    procedure Verify_NotBeforeInFuture_IsValidFalse;
    [Test]
    procedure Verify_NotBeforeInPast_IsValidTrue;
    [Test]
    procedure Decode_ValidToken_ReturnsClaims;
    [Test]
    procedure Decode_InvalidSignature_RaisesECerberoInvalidSignature;
    [Test]
    procedure Claims_NotBefore_ZeroWhenNotSet;
    [Test]
    procedure Claims_NotBefore_ReturnsTimestampWhenSet;
    [Test]
    procedure Claims_IsNotYetValid_TrueWhenNbfInFuture;
    [Test]
    procedure Claims_IsNotYetValid_FalseWhenNbfInPast;
    [Test]
    procedure Claims_IsNotYetValid_FalseWhenNbfAbsent;
  end;

implementation

{ TCerberoJWTTests }

procedure TCerberoJWTTests.Token_MinimalToken_HasThreeParts;
var
  LToken: string;
  LParts: TArray<string>;
begin
  LToken := TCerbero.Token.Subject('u1').SignWith(SECRET);
  LParts := LToken.Split(['.']);
  Assert.AreEqual(3, Length(LParts), 'JWT deve ter exatamente 3 partes');
end;

procedure TCerberoJWTTests.Token_WithSubjectAndClaims_ClaimsAreReadBack;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken := TCerbero.Token
    .Subject('user-42')
    .Issuer('myapp')
    .Audience('api')
    .Claim('role', 'admin')
    .SignWith(SECRET);
  LClaims := TCerbero.Verify(LToken).WithSecret(SECRET).Claims;
  Assert.AreEqual('user-42', LClaims.Subject);
  Assert.AreEqual('myapp',   LClaims.Issuer);
  Assert.AreEqual('api',     LClaims.Audience);
  Assert.AreEqual('admin',   LClaims.Get('role'));
end;

procedure TCerberoJWTTests.Token_WithExpiry_IsNotExpiredImmediately;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('u1').ExpiresIn(3600).SignWith(SECRET);
  LClaims := TCerbero.Verify(LToken).WithSecret(SECRET).Claims;
  Assert.IsFalse(LClaims.IsExpired, 'Token com expiry de 1h nao deve estar expirado');
  Assert.IsTrue(LClaims.ExpiresAt > 0, 'ExpiresAt deve ser positivo');
end;

procedure TCerberoJWTTests.Token_WithNegativeExpiry_IsExpired;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  // ExpiresIn(-10) = expirou 10 segundos atras
  LToken  := TCerbero.Token.Subject('u1').ExpiresIn(-10).SignWith(SECRET);
  LClaims := TCerbero.Verify(LToken).WithSecret(SECRET).Claims;
  Assert.IsTrue(LClaims.IsExpired, 'Token com expiry no passado deve estar expirado');
end;

procedure TCerberoJWTTests.Token_NoExpiry_ExpiresAtIsZeroAndNotExpired;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('u1').SignWith(SECRET);
  LClaims := TCerbero.Verify(LToken).WithSecret(SECRET).Claims;
  Assert.AreEqual(Int64(0), LClaims.ExpiresAt);
  Assert.IsFalse(LClaims.IsExpired);
end;

procedure TCerberoJWTTests.Verify_SameSecret_IsValidTrue;
var
  LToken: string;
begin
  LToken := TCerbero.Token.Subject('u1').ExpiresIn(60).SignWith(SECRET);
  Assert.IsTrue(TCerbero.Verify(LToken).WithSecret(SECRET).IsValid);
end;

procedure TCerberoJWTTests.Verify_WrongSecret_IsValidFalse;
var
  LToken: string;
begin
  LToken := TCerbero.Token.Subject('u1').SignWith(SECRET);
  Assert.IsFalse(TCerbero.Verify(LToken).WithSecret('wrong-secret').IsValid);
end;

procedure TCerberoJWTTests.Verify_TamperedPayload_IsValidFalse;
var
  LToken: string;
  LParts: TArray<string>;
  LTampered: string;
begin
  LToken   := TCerbero.Token.Subject('u1').SignWith(SECRET);
  LParts   := LToken.Split(['.']);
  // Substitui o payload por outro (sub = "hacked"), mantendo a assinatura original
  LTampered := LParts[0] + '.' +
    'eyJzdWIiOiJoYWNrZWQiLCJpYXQiOjB9' + '.' +
    LParts[2];
  Assert.IsFalse(TCerbero.Verify(LTampered).WithSecret(SECRET).IsValid);
end;

procedure TCerberoJWTTests.Verify_MalformedToken_IsValidFalse;
begin
  Assert.IsFalse(TCerbero.Verify('nao.e.um.jwt.valido').WithSecret(SECRET).IsValid);
  Assert.IsFalse(TCerbero.Verify('apenas-uma-parte').WithSecret(SECRET).IsValid);
end;

procedure TCerberoJWTTests.Verify_ExpiredToken_IsValidFalse;
var
  LToken: string;
begin
  LToken := TCerbero.Token.Subject('u1').ExpiresIn(-1).SignWith(SECRET);
  Assert.IsFalse(TCerbero.Verify(LToken).WithSecret(SECRET).IsValid);
end;

procedure TCerberoJWTTests.Claims_ValidToken_SubjectAndIssuerMatch;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('user-99').Issuer('myapp').SignWith(SECRET);
  LClaims := TCerbero.Verify(LToken).WithSecret(SECRET).Claims;
  Assert.AreEqual('user-99', LClaims.Subject);
  Assert.AreEqual('myapp',   LClaims.Issuer);
  Assert.IsTrue(LClaims.IssuedAt > 0, 'iat deve ser preenchido automaticamente');
end;

procedure TCerberoJWTTests.Claims_InvalidSignature_RaisesECerberoInvalidSignature;
var
  LToken: string;
begin
  LToken := TCerbero.Token.Subject('u1').SignWith(SECRET);
  Assert.WillRaise(
    procedure
    begin
      TCerbero.Verify(LToken).WithSecret('bad').Claims;
    end,
    ECerberoInvalidSignature
  );
end;

procedure TCerberoJWTTests.Claims_MalformedToken_RaisesECerberoInvalidToken;
begin
  Assert.WillRaise(
    procedure
    begin
      TCerbero.Verify('a.b').WithSecret(SECRET).Claims;
    end,
    ECerberoInvalidToken
  );
end;

procedure TCerberoJWTTests.Claims_IntAndBoolRoundTrip;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken := TCerbero.Token
    .Subject('u1')
    .ClaimInt('level', 42)
    .ClaimBool('active', True)
    .ClaimBool('banned', False)
    .SignWith(SECRET);
  LClaims := TCerbero.Verify(LToken).WithSecret(SECRET).Claims;
  Assert.AreEqual(Int64(42), LClaims.GetInt('level'));
  Assert.IsTrue(LClaims.GetBool('active'));
  Assert.IsFalse(LClaims.GetBool('banned'));
  Assert.IsTrue(LClaims.Has('level'));
  Assert.IsFalse(LClaims.Has('nonexistent'));
end;

procedure TCerberoJWTTests.Verify_MissingSecret_RaisesECerberoMissingSecret;
var
  LToken: string;
begin
  LToken := TCerbero.Token.Subject('u1').SignWith(SECRET);
  Assert.WillRaise(
    procedure
    begin
      TCerbero.Verify(LToken).IsValid;
    end,
    ECerberoMissingSecret
  );
end;

procedure TCerberoJWTTests.Verify_NotBeforeInFuture_IsValidFalse;
var
  LToken: string;
begin
  // NotBefore(60) = valido somente daqui a 60 segundos
  LToken := TCerbero.Token.Subject('u1').NotBefore(60).SignWith(SECRET);
  Assert.IsFalse(TCerbero.Verify(LToken).WithSecret(SECRET).IsValid,
    'Token com nbf no futuro nao deve ser valido agora');
end;

procedure TCerberoJWTTests.Verify_NotBeforeInPast_IsValidTrue;
var
  LToken: string;
begin
  // NotBefore(-60) = tornou-se valido 60 segundos atras
  LToken := TCerbero.Token.Subject('u1').NotBefore(-60).SignWith(SECRET);
  Assert.IsTrue(TCerbero.Verify(LToken).WithSecret(SECRET).IsValid,
    'Token com nbf no passado deve ser valido agora');
end;

procedure TCerberoJWTTests.Decode_ValidToken_ReturnsClaims;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('decode-test').Issuer('app').SignWith(SECRET);
  LClaims := TCerbero.Decode(LToken, SECRET);
  Assert.AreEqual('decode-test', LClaims.Subject);
  Assert.AreEqual('app', LClaims.Issuer);
end;

procedure TCerberoJWTTests.Decode_InvalidSignature_RaisesECerberoInvalidSignature;
var
  LToken: string;
begin
  LToken := TCerbero.Token.Subject('u1').SignWith(SECRET);
  Assert.WillRaise(
    procedure
    begin
      TCerbero.Decode(LToken, 'wrong-secret');
    end,
    ECerberoInvalidSignature
  );
end;

procedure TCerberoJWTTests.Claims_NotBefore_ZeroWhenNotSet;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('u1').SignWith(SECRET);
  LClaims := TCerbero.Decode(LToken, SECRET);
  Assert.AreEqual(Int64(0), LClaims.NotBefore);
end;

procedure TCerberoJWTTests.Claims_NotBefore_ReturnsTimestampWhenSet;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('u1').NotBefore(120).SignWith(SECRET);
  LClaims := TCerbero.Decode(LToken, SECRET);
  Assert.IsTrue(LClaims.NotBefore > 0, 'NotBefore deve ser um unix timestamp positivo');
end;

procedure TCerberoJWTTests.Claims_IsNotYetValid_TrueWhenNbfInFuture;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('u1').NotBefore(120).SignWith(SECRET);
  LClaims := TCerbero.Decode(LToken, SECRET);
  Assert.IsTrue(LClaims.IsNotYetValid, 'Token com nbf no futuro ainda nao e valido');
end;

procedure TCerberoJWTTests.Claims_IsNotYetValid_FalseWhenNbfInPast;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('u1').NotBefore(-60).SignWith(SECRET);
  LClaims := TCerbero.Decode(LToken, SECRET);
  Assert.IsFalse(LClaims.IsNotYetValid, 'Token com nbf no passado ja e valido');
end;

procedure TCerberoJWTTests.Claims_IsNotYetValid_FalseWhenNbfAbsent;
var
  LToken: string;
  LClaims: ICerberoClaims;
begin
  LToken  := TCerbero.Token.Subject('u1').SignWith(SECRET);
  LClaims := TCerbero.Decode(LToken, SECRET);
  Assert.IsFalse(LClaims.IsNotYetValid, 'Token sem nbf e considerado valido agora');
end;

end.
