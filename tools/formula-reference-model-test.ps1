$ErrorActionPreference='Stop'
$vswhere="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs=& $vswhere -latest -products '*' -property installationPath
if(!$vs){throw 'Visual Studio not found'}
$source=(Resolve-Path tools/formula-reference-model-test.cpp).Path
$include=(Resolve-Path source/Mathomir).Path
$out=Join-Path $env:TEMP 'formula-reference-model.exe'
$bat=Join-Path $env:TEMP 'formula-reference-model.cmd'
@"
@echo off
call "$vs\Common7\Tools\VsDevCmd.bat" -no_logo
cl /nologo /EHsc /std:c++17 /O2 /I"$include" "$source" /Fe"$out"
"@ |Set-Content $bat -Encoding ascii
& cmd.exe /c $bat
if($LASTEXITCODE -ne 0){throw 'Formula reference model compile failed'}
& $out (Join-Path (Resolve-Path source/build).Path 'formula-all-models.mom')
if($LASTEXITCODE -ne 0){throw 'Formula reference model check failed'}
