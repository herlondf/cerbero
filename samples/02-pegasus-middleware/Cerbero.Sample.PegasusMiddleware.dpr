program Cerbero.Sample.PegasusMiddleware;

// Demonstra autenticacao JWT em rotas do Pegasus usando TCerberoMiddleware.
//
// Requisito: Pegasus deve estar no search path (ver .dproj).
//            Execute: .\bootstrap.ps1 na raiz do projeto se necessario.
//
// Endpoints:
//   POST /auth/login   — publico, retorna um JWT
//   GET  /me           — protegido por JWT, retorna subject e role das claims
//   GET  /health       — publico, sem autenticacao

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Pegasus,
  Pegasus.Request,
  Pegasus.Response,
  Pegasus.Proc,
  Cerbero in '..\..\src\Cerbero.pas',
  Cerbero.Interfaces in '..\..\src\Cerbero.Interfaces.pas',
  Cerbero.Core.Types in '..\..\src\Cerbero.Core.Types.pas',
  Cerbero.JWT in '..\..\src\Cerbero.JWT.pas',
  Cerbero.Middleware.Pegasus in '..\..\src\Cerbero.Middleware.Pegasus.pas';

const
  PORT   = 9080;
  SECRET = 'sample-secret-change-in-production';

var
  LApp: TPegasus;

begin
  LApp := TPegasus.Create;
  try
    // --- Rota publica: gera token de demonstracao ---
    LApp.Post('/auth/login',
      procedure(Req: TPegasusRequest; Res: TPegasusResponse)
      var
        LToken: string;
      begin
        LToken := TCerbero.Token
          .Subject('user-demo')
          .Issuer('sample-app')
          .Claim('role', 'user')
          .ExpiresIn(3600)
          .SignWith(SECRET);
        Res.Send('{"token":"' + LToken + '"}');
      end);

    // --- Rota protegida: usa JWTWithClaims para injetar subject no Params ---
    LApp.Get('/me',
      TCerberoMiddleware.JWTWithClaims(SECRET,
        procedure(Req: TPegasusRequest; Claims: ICerberoClaims)
        begin
          Req.Params.AddOrSet('jwt_sub',  Claims.Subject);
          Req.Params.AddOrSet('jwt_role', Claims.Get('role'));
        end),
      procedure(Req: TPegasusRequest; Res: TPegasusResponse)
      var
        LSub: string;
        LRole: string;
      begin
        LSub  := Req.Params.GetOrDefault('jwt_sub',  '');
        LRole := Req.Params.GetOrDefault('jwt_role', '');
        Res.Send('{"subject":"' + LSub + '","role":"' + LRole + '"}');
      end);

    // --- Rota publica: sem autenticacao ---
    LApp.Get('/health',
      procedure(Req: TPegasusRequest; Res: TPegasusResponse)
      begin
        Res.Send('{"status":"ok"}');
      end);

    WriteLn('Servidor iniciado na porta ', PORT);
    WriteLn('  POST /auth/login  -> obter JWT');
    WriteLn('  GET  /me          -> rota protegida (Authorization: Bearer <token>)');
    WriteLn('  GET  /health      -> rota publica');
    WriteLn('Pressione Enter para parar.');

    LApp.Listen(PORT);
    ReadLn;
    LApp.StopListen;
  finally
    LApp.Free;
  end;
end.
