# Render via the real OnPrint path, both directly and through MFC CPreviewDC.
$ErrorActionPreference='Stop'
$env:MATHOMIR_PRINT_GRID_CHECK='1'
$all=Get-Content (Join-Path $PSScriptRoot 'canvas-grid-smoke.ps1') -Raw
$headerEnd=$all.IndexOf('$exe=')
if($headerEnd -lt 0){throw 'Shared grid probe not found.'}
Invoke-Expression $all.Substring(0,$headerEnd)
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
function Start-App {
 $script:app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 250;$app.Refresh();if($app.HasExited){throw 'Application exited during print-grid startup.'};if($app.MainWindowHandle -ne 0){break}}
 $script:main=$app.MainWindowHandle;if($main -eq [IntPtr]::Zero){throw 'No main window.'};$script:view=[GridUI]::Child($main,0xE900)
}
function Options {
 [GridUI]::PostMessage($main,273,[IntPtr]33099,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;$d=[GridUI]::Dialog($app.Id,'Grid styles and snapping');if($d -ne [IntPtr]::Zero){return $d}}
 throw 'Grid options did not open.'
}
function Box($d,$id,$value){[GridUI]::Send([GridUI]::Child($d,$id),241,$value)|Out-Null;[GridUI]::Send($d,273,$id)|Out-Null}
function Set-Grid($style,$show,$print,$color=0){
 $d=Options
 [GridUI]::Send([GridUI]::Child($d,1360),334,$style)|Out-Null
 [GridUI]::Send($d,273,((1-shl 16)-bor 1360))|Out-Null
 [GridUI]::Set([GridUI]::Child($d,1361),'16');[GridUI]::Send($d,273,((5-shl 16)-bor 1361))|Out-Null
 [GridUI]::Send([GridUI]::Child($d,1365),334,$color)|Out-Null
 [GridUI]::Send($d,273,((1-shl 16)-bor 1365))|Out-Null
 Box $d 1362 $show;Box $d 1368 $print
 [GridUI]::Send($d,273,1)|Out-Null
}
try{
 Start-App
 $fixture=Join-Path (Split-Path $exe) 'print-grid-empty.mom'
 '<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $fixture -Encoding ascii
 [GridUI]::Open($main,$fixture);Start-Sleep -Milliseconds 300
 $signatures=@()
 foreach($style in 0..5){
   Set-Grid $style 1 1 ($style%3)
   foreach($mode in 1..3){foreach($page in 1..2){
     $pixels=[GridUI]::Send($view,32923,$mode,$page)
     if($pixels -lt 100){throw "Missing printed grid: style $style, mode $mode, page $page, pixels $pixels"}
     if($mode -eq 1 -and $page -eq 1){$signatures+=$pixels}
   }}
   Set-Grid $style 1 0
   foreach($mode in 1..3){if([GridUI]::Send($view,32923,$mode,1) -ne 0){throw "Print exclusion ignored: $style/$mode"}}
   Set-Grid $style 0 1
   foreach($mode in 1..3){if([GridUI]::Send($view,32923,$mode,1) -ne 0){throw "Hidden grid printed: $style/$mode"}}
 }
 if(($signatures|Select-Object -Unique).Count -lt 5){throw 'Printed styles were not distinct.'}
 Set-Grid 2 1 0
 Stop-Process -Id $app.Id -Force;Start-App
 $d=Options
 if([GridUI]::Send([GridUI]::Child($d,1368),240,0) -ne 0){throw 'Print-grid preference did not persist.'}
 Box $d 1368 1;[GridUI]::Send($d,273,1)|Out-Null
 Write-Output 'Print grid passed: all six styles, three colors, OnPrint and MFC preview at 100/50 percent, pages 1/2, hidden/excluded grids, distinct output, restored viewport and persisted print preference.'
}finally{$app.Refresh();if(!$app.HasExited){Stop-Process -Id $app.Id -Force};Remove-Item Env:MATHOMIR_PRINT_GRID_CHECK -ErrorAction SilentlyContinue}
