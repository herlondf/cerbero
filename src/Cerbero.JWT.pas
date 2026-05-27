unit Cerbero.JWT;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  Cerbero.Core.Types,
  Cerbero.Interfaces;

type
  TCerberoClaims = class(TInterfacedObject, ICerberoClaims)
  private
    FPayload: TJSONObject;
    function JsonString(const AName: string): string;
    function JsonInt(const AName: string): Int64;
  public
    constructor Create(const APayload: TJSONObject);
    destructor Destroy; override;
    function Subject: string;
    function Issuer: string;
    function Audience: string;
    function ExpiresAt: Int64;
    function IssuedAt: Int64;
    function IsExpired: Boolean;
    function Get(const AName: string): string;
    function GetInt(const AName: string): Int64;
    function GetBool(const AName: string): Boolean;
    function NotBefore: Int64;
    function IsNotYetValid: Boolean;
    function Has(const AName: string): Boolean;
  end;

  TCerberoJWTBuilder = class(TInterfacedObject, ICerberoTokenBuilder)
  private
    FPayload: TJSONObject;
    function BuildHeader: string;
    function BuildPayload: string;
  public
    constructor Create;
    destructor Destroy; override;
    function Subject(const AValue: string): ICerberoTokenBuilder;
    function Issuer(const AValue: string): ICerberoTokenBuilder;
    function Audience(const AValue: string): ICerberoTokenBuilder;
    function ExpiresIn(ASeconds: Integer): ICerberoTokenBuilder;
    function NotBefore(ASeconds: Integer): ICerberoTokenBuilder;
    function Claim(const AName, AValue: string): ICerberoTokenBuilder;
    function ClaimInt(const AName: string; AValue: Int64): ICerberoTokenBuilder;
    function ClaimBool(const AName: string; AValue: Boolean): ICerberoTokenBuilder;
    function SignWith(const ASecret: string): string;
  end;

  TCerberoJWTVerifier = class(TInterfacedObject, ICerberoVerifier)
  private
    FToken: string;
    FSecret: string;
    FParts: TArray<string>;
    function SplitToken: Boolean;
    function ComputeSignature(const AHeaderB64, APayloadB64: string): string;
    function ParsePayload: TJSONObject;
  public
    constructor Create(const AToken: string);
    function WithSecret(const ASecret: string): ICerberoVerifier;
    function IsValid: Boolean;
    function Claims: ICerberoClaims;
  end;

function Base64URLEncode(const ABytes: TBytes): string;
function Base64URLDecode(const AStr: string): TBytes;
function NowAsUnix: Int64;

implementation

uses
  System.Hash,
  System.NetEncoding;

{ Helpers }

function Base64URLEncode(const ABytes: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(ABytes);
  Result := Result.Replace('+', '-', [rfReplaceAll]);
  Result := Result.Replace('/', '_', [rfReplaceAll]);
  Result := Result.Replace('=', '',  [rfReplaceAll]);
end;

function Base64URLDecode(const AStr: string): TBytes;
var
  LB64: string;
  LPad: Integer;
begin
  LB64 := AStr
    .Replace('-', '+', [rfReplaceAll])
    .Replace('_', '/', [rfReplaceAll]);
  LPad := (4 - (Length(LB64) mod 4)) mod 4;
  LB64 := LB64 + StringOfChar('=', LPad);
  Result := TNetEncoding.Base64.DecodeStringToBytes(LB64);
end;

function NowAsUnix: Int64;
begin
  Result := DateTimeToUnix(Now, False);
end;

{ TCerberoClaims }

constructor TCerberoClaims.Create(const APayload: TJSONObject);
begin
  inherited Create;
  FPayload := APayload;
end;

destructor TCerberoClaims.Destroy;
begin
  FPayload.Free;
  inherited;
end;

function TCerberoClaims.JsonString(const AName: string): string;
var
  LVal: TJSONValue;
begin
  LVal := FPayload.GetValue(AName);
  if Assigned(LVal) then
    Result := LVal.Value
  else
    Result := '';
end;

function TCerberoClaims.JsonInt(const AName: string): Int64;
var
  LVal: TJSONValue;
begin
  LVal := FPayload.GetValue(AName);
  if Assigned(LVal) then
    Result := (LVal as TJSONNumber).AsInt64
  else
    Result := 0;
end;

function TCerberoClaims.Subject: string;
begin
  Result := JsonString(CERBERO_CLAIM_SUB);
end;

function TCerberoClaims.Issuer: string;
begin
  Result := JsonString(CERBERO_CLAIM_ISS);
end;

function TCerberoClaims.Audience: string;
begin
  Result := JsonString(CERBERO_CLAIM_AUD);
end;

function TCerberoClaims.ExpiresAt: Int64;
begin
  Result := JsonInt(CERBERO_CLAIM_EXP);
end;

function TCerberoClaims.IssuedAt: Int64;
begin
  Result := JsonInt(CERBERO_CLAIM_IAT);
end;

function TCerberoClaims.IsExpired: Boolean;
var
  LExp: Int64;
begin
  LExp := ExpiresAt;
  if LExp = 0 then
    Result := False
  else
    Result := NowAsUnix > LExp;
end;

function TCerberoClaims.NotBefore: Int64;
begin
  Result := JsonInt(CERBERO_CLAIM_NBF);
end;

function TCerberoClaims.IsNotYetValid: Boolean;
var
  LNbf: Int64;
begin
  LNbf := NotBefore;
  if LNbf = 0 then
    Result := False
  else
    Result := NowAsUnix < LNbf;
end;

function TCerberoClaims.Get(const AName: string): string;
begin
  Result := JsonString(AName);
end;

function TCerberoClaims.GetInt(const AName: string): Int64;
begin
  Result := JsonInt(AName);
end;

function TCerberoClaims.GetBool(const AName: string): Boolean;
var
  LVal: TJSONValue;
begin
  LVal := FPayload.GetValue(AName);
  Result := Assigned(LVal) and (LVal is TJSONTrue);
end;

function TCerberoClaims.Has(const AName: string): Boolean;
begin
  Result := Assigned(FPayload.GetValue(AName));
end;

{ TCerberoJWTBuilder }

constructor TCerberoJWTBuilder.Create;
begin
  inherited Create;
  FPayload := TJSONObject.Create;
end;

destructor TCerberoJWTBuilder.Destroy;
begin
  FPayload.Free;
  inherited;
end;

function TCerberoJWTBuilder.BuildHeader: string;
var
  LHeader: TJSONObject;
begin
  LHeader := TJSONObject.Create;
  try
    LHeader.AddPair('alg', CERBERO_ALG_HS256);
    LHeader.AddPair('typ', CERBERO_TYP_JWT);
    Result := Base64URLEncode(TEncoding.UTF8.GetBytes(LHeader.ToJSON));
  finally
    LHeader.Free;
  end;
end;

function TCerberoJWTBuilder.BuildPayload: string;
begin
  if not Assigned(FPayload.GetValue(CERBERO_CLAIM_IAT)) then
    FPayload.AddPair(CERBERO_CLAIM_IAT, TJSONNumber.Create(NowAsUnix));
  Result := Base64URLEncode(TEncoding.UTF8.GetBytes(FPayload.ToJSON));
end;

function TCerberoJWTBuilder.Subject(const AValue: string): ICerberoTokenBuilder;
begin
  FPayload.AddPair(CERBERO_CLAIM_SUB, AValue);
  Result := Self;
end;

function TCerberoJWTBuilder.Issuer(const AValue: string): ICerberoTokenBuilder;
begin
  FPayload.AddPair(CERBERO_CLAIM_ISS, AValue);
  Result := Self;
end;

function TCerberoJWTBuilder.Audience(const AValue: string): ICerberoTokenBuilder;
begin
  FPayload.AddPair(CERBERO_CLAIM_AUD, AValue);
  Result := Self;
end;

function TCerberoJWTBuilder.ExpiresIn(ASeconds: Integer): ICerberoTokenBuilder;
begin
  FPayload.AddPair(CERBERO_CLAIM_EXP, TJSONNumber.Create(NowAsUnix + ASeconds));
  Result := Self;
end;

function TCerberoJWTBuilder.NotBefore(ASeconds: Integer): ICerberoTokenBuilder;
begin
  FPayload.AddPair(CERBERO_CLAIM_NBF, TJSONNumber.Create(NowAsUnix + ASeconds));
  Result := Self;
end;

function TCerberoJWTBuilder.Claim(const AName, AValue: string): ICerberoTokenBuilder;
begin
  FPayload.AddPair(AName, AValue);
  Result := Self;
end;

function TCerberoJWTBuilder.ClaimInt(const AName: string; AValue: Int64): ICerberoTokenBuilder;
begin
  FPayload.AddPair(AName, TJSONNumber.Create(AValue));
  Result := Self;
end;

function TCerberoJWTBuilder.ClaimBool(const AName: string; AValue: Boolean): ICerberoTokenBuilder;
begin
  if AValue then
    FPayload.AddPair(AName, TJSONTrue.Create)
  else
    FPayload.AddPair(AName, TJSONFalse.Create);
  Result := Self;
end;

function TCerberoJWTBuilder.SignWith(const ASecret: string): string;
var
  LHeaderB64: string;
  LPayloadB64: string;
  LMessage: string;
  LSig: string;
begin
  if ASecret = '' then
    raise ECerberoMissingSecret.Create('Secret cannot be empty');
  LHeaderB64  := BuildHeader;
  LPayloadB64 := BuildPayload;
  LMessage    := LHeaderB64 + '.' + LPayloadB64;
  LSig := Base64URLEncode(
    THashSHA2.GetHMACAsBytes(
      TEncoding.UTF8.GetBytes(LMessage),
      TEncoding.UTF8.GetBytes(ASecret),
      THashSHA2.TSHA2Version.SHA256
    )
  );
  Result := LMessage + '.' + LSig;
end;

{ TCerberoJWTVerifier }

constructor TCerberoJWTVerifier.Create(const AToken: string);
begin
  inherited Create;
  FToken := AToken;
end;

function TCerberoJWTVerifier.WithSecret(const ASecret: string): ICerberoVerifier;
begin
  FSecret := ASecret;
  Result := Self;
end;

function TCerberoJWTVerifier.SplitToken: Boolean;
begin
  FParts := FToken.Split(['.']);
  Result := Length(FParts) = 3;
end;

function TCerberoJWTVerifier.ComputeSignature(const AHeaderB64, APayloadB64: string): string;
var
  LMessage: string;
begin
  LMessage := AHeaderB64 + '.' + APayloadB64;
  Result := Base64URLEncode(
    THashSHA2.GetHMACAsBytes(
      TEncoding.UTF8.GetBytes(LMessage),
      TEncoding.UTF8.GetBytes(FSecret),
      THashSHA2.TSHA2Version.SHA256
    )
  );
end;

function TCerberoJWTVerifier.ParsePayload: TJSONObject;
var
  LBytes: TBytes;
  LJSON: string;
  LVal: TJSONValue;
begin
  LBytes := Base64URLDecode(FParts[1]);
  LJSON  := TEncoding.UTF8.GetString(LBytes);
  LVal   := TJSONObject.ParseJSONValue(LJSON);
  if not (LVal is TJSONObject) then
  begin
    LVal.Free;
    raise ECerberoInvalidToken.Create('Invalid JWT payload');
  end;
  Result := LVal as TJSONObject;
end;

function TCerberoJWTVerifier.IsValid: Boolean;
var
  LPayload: TJSONObject;
  LExp: TJSONValue;
  LNbf: TJSONValue;
  LNow: Int64;
begin
  Result := False;
  if FSecret = '' then
    raise ECerberoMissingSecret.Create('Secret not set — call WithSecret first');
  if not SplitToken then
    Exit;
  if ComputeSignature(FParts[0], FParts[1]) <> FParts[2] then
    Exit;
  try
    LPayload := ParsePayload;
    try
      LNow := NowAsUnix;
      LExp := LPayload.GetValue(CERBERO_CLAIM_EXP);
      if Assigned(LExp) and (LNow > (LExp as TJSONNumber).AsInt64) then
        Exit; // expirado
      LNbf := LPayload.GetValue(CERBERO_CLAIM_NBF);
      if Assigned(LNbf) and (LNow < (LNbf as TJSONNumber).AsInt64) then
        Exit; // ainda nao valido
      Result := True;
    finally
      LPayload.Free;
    end;
  except
    Result := False;
  end;
end;

function TCerberoJWTVerifier.Claims: ICerberoClaims;
begin
  if FSecret = '' then
    raise ECerberoMissingSecret.Create('Secret not set — call WithSecret first');
  if not SplitToken then
    raise ECerberoInvalidToken.Create('Malformed JWT token');
  if ComputeSignature(FParts[0], FParts[1]) <> FParts[2] then
    raise ECerberoInvalidSignature.Create('JWT signature validation failed');
  Result := TCerberoClaims.Create(ParsePayload);
end;

end.
