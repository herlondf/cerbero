unit Cerbero.Interfaces;

interface

type
  ICerberoClaims = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    function Subject: string;
    function Issuer: string;
    function Audience: string;
    function ExpiresAt: Int64;
    function IssuedAt: Int64;
    function IsExpired: Boolean;
    function Get(const AName: string): string;
    function GetInt(const AName: string): Int64;
    function GetBool(const AName: string): Boolean;
    function Has(const AName: string): Boolean;
  end;

  ICerberoTokenBuilder = interface
    ['{B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D6E}']
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

  ICerberoVerifier = interface
    ['{C3D4E5F6-A7B8-4C9D-0E1F-2A3B4C5D6E7F}']
    function WithSecret(const ASecret: string): ICerberoVerifier;
    function IsValid: Boolean;
    function Claims: ICerberoClaims;
  end;

implementation

end.
