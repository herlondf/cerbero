unit Cerbero.Middleware.Pegasus;

// Middleware Pegasus para autenticacao JWT.
// Requer Pegasus no search path.
//
// Uso:
//   App.Use(TCerberoMiddleware.JWT('meu-secret'));
//
//   // Para rotas especificas:
//   App.Get('/perfil', TCerberoMiddleware.JWT('meu-secret'),
//     procedure(Req: TPegasusRequest; Res: TPegasusResponse)
//     begin
//       LClaims := TCerbero.Decode(Req.Headers.GetOrDefault('Authorization','').Substring(7), 'meu-secret');
//       Res.Send(LClaims.Subject);
//     end);

interface

uses
  System.SysUtils,
  Pegasus.Callback,
  Pegasus.Request,
  Pegasus.Response,
  Pegasus.Proc;

type
  TCerberoMiddleware = class
  public
    /// Valida o Bearer JWT no header Authorization.
    /// - Token ausente ou invalido: responde 401 e interrompe a chain.
    /// - Token valido: chama Next e a requisicao prossegue.
    class function JWT(const ASecret: string): TPegasusCallback; static;
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

class function TCerberoMiddleware.JWT(const ASecret: string): TPegasusCallback;
begin
  Result :=
    procedure(Req: TPegasusRequest; Res: TPegasusResponse; Next: TNextProc)
    var
      LAuth: string;
      LToken: string;
    begin
      LAuth := Req.Headers.GetOrDefault(HEADER_AUTHORIZATION, '');
      if not LAuth.StartsWith(BEARER_PREFIX, True) then
      begin
        Res.Status(HTTP_UNAUTHORIZED).Send(MSG_UNAUTHORIZED);
        Exit;
      end;
      LToken := LAuth.Substring(Length(BEARER_PREFIX));
      try
        if not TCerbero.Verify(LToken).WithSecret(ASecret).IsValid then
        begin
          Res.Status(HTTP_UNAUTHORIZED).Send(MSG_UNAUTHORIZED);
          Exit;
        end;
      except
        Res.Status(HTTP_UNAUTHORIZED).Send(MSG_UNAUTHORIZED);
        Exit;
      end;
      Next;
    end;
end;

end.
