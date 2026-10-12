$ErrorActionPreference='Stop'
$vswhere="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$command='"'+$vs+'\Common7\Tools\VsDevCmd.bat" -no_logo -arch=x86 && cl /nologo /EHsc /W4 /I source\Mathomir tools\ai-presentation-test.cpp /Fe:source\build\ai-presentation-test.exe /Fo:source\build\ai-presentation-test.obj && source\build\ai-presentation-test.exe'
& cmd /d /s /c $command
if($LASTEXITCODE -ne 0){throw 'AI presentation regression failed.'}

$command='"'+$vs+'\Common7\Tools\VsDevCmd.bat" -no_logo -arch=x86 && cl /nologo /EHsc /W4 /I source\Mathomir tools\ai-native-presentation-test.cpp /Fe:source\build\ai-native-presentation-test.exe /Fo:source\build\ai-native-presentation-test.obj && source\build\ai-native-presentation-test.exe'
& cmd /d /s /c $command
if($LASTEXITCODE -ne 0){throw 'Native math presentation regression failed.'}
