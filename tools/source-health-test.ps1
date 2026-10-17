$ErrorActionPreference='Stop'
python ./tools/source-health-test.py --emit source/build/source-health-test.cpp
if($LASTEXITCODE -ne 0){throw 'Could not extract native source health functions.'}
$vswhere="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(!$vs){throw 'Visual C++ compiler was not found.'}
$command='"'+$vs+'\Common7\Tools\VsDevCmd.bat" -no_logo -arch=x86 && cl /nologo /EHsc /W4 source\build\source-health-test.cpp /Fe:source\build\source-health-test.exe /Fo:source\build\source-health-test.obj && source\build\source-health-test.exe'
& cmd /d /s /c $command
if($LASTEXITCODE -ne 0){throw 'Native source health regression failed.'}
