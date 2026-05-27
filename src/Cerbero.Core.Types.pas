unit Cerbero.Core.Types;

interface

uses
  System.SysUtils;

type
  ECerberoException        = class(Exception);
  ECerberoInvalidToken     = class(ECerberoException);
  ECerberoExpiredToken     = class(ECerberoException);
  ECerberoInvalidSignature = class(ECerberoException);
  ECerberoMissingSecret    = class(ECerberoException);

const
  CERBERO_ALG_HS256 = 'HS256';
  CERBERO_TYP_JWT   = 'JWT';
  CERBERO_CLAIM_SUB = 'sub';
  CERBERO_CLAIM_ISS = 'iss';
  CERBERO_CLAIM_AUD = 'aud';
  CERBERO_CLAIM_EXP = 'exp';
  CERBERO_CLAIM_IAT = 'iat';
  CERBERO_CLAIM_NBF = 'nbf';

implementation

end.
