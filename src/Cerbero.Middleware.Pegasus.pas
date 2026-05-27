unit Cerbero.Middleware.Pegasus;

// Middleware Pegasus para autenticacao JWT.
// Requer Pegasus no search path.
//
// --- JWT (apenas valida, rejeita sem token) ---
//   App.Use(TCerberoMiddleware.JWT('secret'));
//
// --- JWTWithClaims (valida e injeta claims no request) ---
//   App.Get('/me',
//     TCerberoMiddleware.JWTWithClaims('secret',
//       procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
//       begin
//         Req.Params.AddOrSet('jwt_sub',  Claims.Subject);
//         Req.Params.AddOrSet('jwt_role', Claims.Get('role'));
//       end),
//     procedure(Req: TPegasusRequest; Res: TPegasusResponse)
//     begin
//       Res.Send(Req.Params.GetOrDefault('jwt_sub', ''));
//     end);
//
// --- JWTOptional (passa adiante mesmo sem token; injeta claims se presente) ---
//   App.Get('/feed',
//     TCerberoMiddleware.JWTOptional('secret',
//       procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
//       begin
//         Req.Params.AddOrSet('jwt_sub', Claims.Subject);
//       end),
//     ...);

interface

uses
  System.SysUtils,
  Pegasus.Callback,
  Pegasus.Request,
  Pegasus.Response,
  Pegasus.Proc,
  Cerbero.Interfaces;

type
  TCerberoClaimsInjector = reference to procedure(
    Req: TPegasusRequest; Claims: ICerberoClaims);

  TCerberoMiddleware = class
  public
    /// Valida o Bearer JWT no header Authorization.
    /// Token ausente/invalido: responde 401 e interrompe a chain.
    /// Token valido: chama Next.
    class function JWT(const ASecret: string): TPegasusCallback; static;

    /// Igual ao JWT, mas apos validar chama AOnValid com o request e as claims
    /// antes de invocar Next. Use para armazenar claims no Req.Params ou
    /// qualquer outro mecanismo de contexto da sua aplicacao.
    class function JWTWithClaims(
      const ASecret: string;
      const AOnValid: TCerberoClaimsInjector): TPegasusCallback; static;

    /// Variante opcional: se houver Bearer token valido, chama AOnValid e segue.
    /// Se nao houver token ou o token for invalido, chama Next sem rejeitar.
    /// Util para rotas publicas que enriquecem contexto quando o usuario esta logado.
    class function JWTOptional(
      const ASecret: string;
      const AOnValid: TCerberoClaimsInjector): TPegasusCallback; static;
  end;

implementation

uses
  Cerbero,
  Cerbero.Core.Types;

const
  BEARER_PREFIX        = 'Bearer ';
  HTTP_UNAUTHORIZED    = 401;
  MSG_UNAUTHORIZED     = 'Unauthorized';
  HEADER_AUTHORIZATION = 'Authorization';

function ExtractBearerToken(const AAuthHeader: string; out AToken: string): Boolean;
begin
  Result := AAuthHeader.StartsWith(BEARER_PREFIX, True);
  if Result then
    AToken := AAuthHeader.Substring(Length(BEARER_PREFIX));
end;

procedure SendUnauthorized(Res: TPegasusResponse);
begin
  Res.Status(HTTP_UNAUTHORIZED).Send(MSG_UNAUTHORIZED);
end;

class function TCerberoMiddleware.JWT(const ASecret: string): TPegasusCallback;
begin
  Result :=
    procedure(Req: TPegasusRequest; Res: TPegasusResponse; Next: TNextProc)
    var
      LToken: string;
    begin
      if not ExtractBearerToken(Req.Headers.GetOrDefault(HEADER_AUTHORIZATION, ''), LToken) then
      begin
        SendUnauthorized(Res);
        Exit;
      end;
      try
        if not TCerbero.Verify(LToken).WithSecret(ASecret).IsValid then
        begin
          SendUnauthorized(Res);
          Exit;
        end;
      except
        SendUnauthorized(Res);
        Exit;
      end;
      Next;
    end;
end;

class function TCerberoMiddleware.JWTWithClaims(
  const ASecret: string;
  const AOnValid: TCerberoClaimsInjector): TPegasusCallback;
begin
  Result :=
    procedure(Req: TPegasusRequest; Res: TPegasusResponse; Next: TNextProc)
    var
      LToken: string;
      LClaims: ICerberoClaims;
    begin
      if not ExtractBearerToken(Req.Headers.GetOrDefault(HEADER_AUTHORIZATION, ''), LToken) then
      begin
        SendUnauthorized(Res);
        Exit;
      end;
      try
        LClaims := TCerbero.Decode(LToken, ASecret);
      except
        SendUnauthorized(Res);
        Exit;
      end;
      if Assigned(AOnValid) then
        AOnValid(Req, LClaims);
      Next;
    end;
end;

class function TCerberoMiddleware.JWTOptional(
  const ASecret: string;
  const AOnValid: TCerberoClaimsInjector): TPegasusCallback;
begin
  Result :=
    procedure(Req: TPegasusRequest; Res: TPegasusResponse; Next: TNextProc)
    var
      LToken: string;
      LClaims: ICerberoClaims;
    begin
      if ExtractBearerToken(Req.Headers.GetOrDefault(HEADER_AUTHORIZATION, ''), LToken) then
      begin
        try
          LClaims := TCerbero.Decode(LToken, ASecret);
          if Assigned(AOnValid) then
            AOnValid(Req, LClaims);
        except
          // token invalido/expirado em rota opcional — ignora e segue
        end;
      end;
      Next;
    end;
end;

end.
