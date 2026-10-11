$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
try {
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle
 foreach($folder in @('path example one','path example two')){
  $directory=Join-Path (Split-Path $exe) $folder;New-Item -ItemType Directory -Force $directory|Out-Null
  $path=Join-Path $directory 'same name.mom';'<?xml version="1.0"?><mathomir><o t="1" X="80" Y="80"><ex><var t="x" f="00" /></ex></o></mathomir>'|Set-Content $path -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$path);Start-Sleep -Milliseconds 400
  $title=[MathomirUiProbe]::Text($main);if(!$title.Contains($path)){throw "Full current path missing from title: $title"}
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;Start-Sleep -Milliseconds 100
  if(![MathomirUiProbe]::Text($main).Contains($path)){throw 'Save dropped the current path from the title'}
 }
 [MathomirUiProbe]::Send($main,273,0xE100)|Out-Null;Start-Sleep -Milliseconds 300
 if([MathomirUiProbe]::Text($main).Contains('same name.mom')){throw 'Untitled document retained an old file path'}
 Write-Output 'Title path passed: full folder and filename, spaces, same-named files in different directories, normal Save, new untitled document.'
}finally{$app.Refresh();if(!$app.HasExited){$app.Kill();$app.WaitForExit()}}
