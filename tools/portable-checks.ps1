$ErrorActionPreference='Stop'
$vswhere="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(!$vs){throw 'Visual C++ compiler was not found.'}
New-Item -ItemType Directory -Force source/build | Out-Null
# Compile every checked-in C++ check. A new test is automatically included.
foreach($test in Get-ChildItem (Join-Path $PSScriptRoot '*.cpp') | Sort-Object Name){
    $relative='tools\'+$test.Name
    $output='source\build\'+$test.BaseName
    $arguments=if($test.Name -eq 'formula-reference-model-test.cpp'){' source\build\formula-all-models.mom'}else{''}
    $command='"'+$vs+'\Common7\Tools\VsDevCmd.bat" -no_logo -arch=x86 && cl /nologo /EHsc /W4 /I source\Mathomir '+$relative+' /Fe:'+ $output+'.exe /Fo:'+ $output+'.obj && '+ $output+'.exe'+$arguments
    & cmd /d /s /c $command
    if($LASTEXITCODE -ne 0){throw ('C++ regression failed: '+$test.Name)}
}
