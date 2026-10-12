$ErrorActionPreference='Stop'
$vswhere="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(!$vs){throw 'Visual C++ compiler was not found.'}
$command='"'+$vs+'\Common7\Tools\VsDevCmd.bat" -no_logo -arch=x86 && cl /nologo /EHsc /W4 /I source\Mathomir tools\integral-area-test.cpp /Fe:source\build\integral-area-test.exe /Fo:source\build\integral-area-test.obj && source\build\integral-area-test.exe'
& cmd /d /s /c $command
if($LASTEXITCODE -ne 0){throw 'Integral-area numerical regression failed.'}
