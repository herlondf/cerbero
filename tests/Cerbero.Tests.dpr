program Cerbero.Tests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Cerbero.Tests.JWT in 'units\Cerbero.Tests.JWT.pas';

const
  EXIT_ERRORS = 1;

var
  LRunner : ITestRunner;
  LResults: IRunResults;
  LLogger : ITestLogger;

begin
  try
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName + ': ' + E.Message);
      ExitCode := EXIT_ERRORS;
    end;
  end;
end.
