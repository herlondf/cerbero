#Requires -Version 5.1
param([switch]$Check)

Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DepsFile  = Join-Path $ScriptDir 'deps.json'

if (-not (Test-Path $DepsFile)) {
  Write-Host "  ERRO deps.json nao encontrado em $ScriptDir" -ForegroundColor Red
  exit 1
}

$Deps    = (Get-Content $DepsFile -Raw | ConvertFrom-Json).deps
$HasGh   = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
$Errors  = 0

Write-Host ""
Write-Host "Cerbero - bootstrap de dependencias" -ForegroundColor White
Write-Host "------------------------------------" -ForegroundColor DarkGray
Write-Host ""

if ($Deps.Count -eq 0) {
  Write-Host "  Nenhuma dependencia configurada." -ForegroundColor DarkGray
  Write-Host ""
  exit 0
}

function Test-GithubRelease([string]$Url, [string]$Ref) {
  if ($Ref -notmatch '^v\d') { return }
  if (-not $HasGh) {
    Write-Host "  !! gh CLI nao encontrado; validacao de release ignorada." -ForegroundColor DarkGray
    return
  }
  $Repo = $Url -replace '\.git$','' -replace '.*github\.com[:/]',''
  gh release view $Ref --repo $Repo *>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "  !! Release $Ref nao encontrada no GitHub." -ForegroundColor Yellow
    Write-Host "     Crie em: https://github.com/$Repo/releases/new?tag=$Ref" -ForegroundColor Yellow
  } else {
    Write-Host "  OK Release $Ref existe no GitHub." -ForegroundColor Green
  }
}

foreach ($Dep in $Deps) {
  $TargetPath = Join-Path $ScriptDir $Dep.path
  $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)

  Write-Host "[$($Dep.name)]" -ForegroundColor Magenta

  Test-GithubRelease -Url $Dep.url -Ref $Dep.ref

  if (-not $Check) {
    if (-not (Test-Path $TargetPath)) {
      Write-Host "  >> Clonando $($Dep.url) (ref: $($Dep.ref)) ..." -ForegroundColor Cyan
      git clone --depth 1 --branch $Dep.ref --quiet $Dep.url $TargetPath
      if ($LASTEXITCODE -ne 0) {
        Write-Host "  !! Clone com --branch falhou; tentando sem filtro..." -ForegroundColor Yellow
        git clone --quiet $Dep.url $TargetPath
        if ($LASTEXITCODE -ne 0) {
          Write-Host "  ERRO Falha ao clonar $($Dep.url)" -ForegroundColor Red
          $Errors++
          continue
        }
        Push-Location $TargetPath
        git checkout --quiet $Dep.ref
        Pop-Location
      }
      Write-Host "  OK Clonado em $TargetPath" -ForegroundColor Green
    } else {
      Write-Host "  >> Atualizando para ref $($Dep.ref) ..." -ForegroundColor Cyan
      Push-Location $TargetPath
      git fetch --depth 1 --quiet origin $Dep.ref
      git checkout --quiet $Dep.ref
      Pop-Location
      Write-Host "  OK Atualizado" -ForegroundColor Green
    }
  } else {
    if (-not (Test-Path $TargetPath)) {
      Write-Host "  !! Pasta nao encontrada: $TargetPath" -ForegroundColor Yellow
      $Errors++
    } else {
      Write-Host "  OK Pasta existe: $TargetPath" -ForegroundColor Green
    }
  }

  foreach ($RelPath in $Dep.validate) {
    $FullPath = Join-Path $TargetPath $RelPath
    if (Test-Path $FullPath) {
      Write-Host "  OK $RelPath" -ForegroundColor Green
    } else {
      Write-Host "  ERRO Caminho ausente: $FullPath" -ForegroundColor Red
      $Errors++
    }
  }

  Write-Host ""
}

if ($Errors -eq 0) {
  Write-Host "Todas as dependencias estao prontas." -ForegroundColor Green
  exit 0
} else {
  $n = $Errors
  Write-Host "$n problema(s) encontrado(s). Verifique acima." -ForegroundColor Red
  exit 1
}
