$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RelationProbe {
 [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int command);
}
'@
function Check($ok,$why){if(!$ok){throw $why}}
function Capture($h,$name){$r=[MathomirUiProbe]::WindowRect($h);$b=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[Drawing.Graphics]::FromImage($b);try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size);$b.Save((Join-Path $folder $name))}finally{$g.Dispose();$b.Dispose()}}
function Dialog {
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33106,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 50;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($app.Id,'Relations and parametric curves');if($d -ne [IntPtr]::Zero){return $d}}
 throw 'Relation editor did not open'
}
function Apply($d){[MathomirUiProbe]::PostMessage($d,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null;for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;if(![MathomirUiProbe]::IsWindowVisible($d)){return}};throw 'Relation editor did not close'}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $fixture -Raw)}
function HoverGraph {[MathomirUiProbe]::Mouse($view,512,0,290,240);Start-Sleep -Milliseconds 150}
function Blank($name){$script:fixture=Join-Path $folder ('relation-'+$name+'.mom');'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $fixture -Encoding ascii;[MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 400;[MathomirUiProbe]::Send($main,273,32775)|Out-Null}
function Place {[MathomirUiProbe]::Mouse($view,512,0,100,100);[MathomirUiProbe]::Mouse($view,513,1,100,100);[MathomirUiProbe]::Mouse($view,514,0,100,100);[MathomirUiProbe]::Send($view,258,27)|Out-Null;[MathomirUiProbe]::Mouse($view,512,0,850,50);Start-Sleep -Seconds 2}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe
$env:MATHOMIR_GRAPH_DIAGNOSTICS='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start';[RelationProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 Blank 'equations';$d=Dialog
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1423)) -eq 'x^2+y^2=25') 'Circle default missing'
 $preview=[MathomirUiProbe]::Child($d,1434);$r=[MathomirUiProbe]::ClientRect($preview)
 Check ([MathomirUiProbe]::CountColor($preview,5,5,($r.Right-10),($r.Bottom-10),0) -gt 150) 'Circle preview absent'
 Capture $d 'relation-circle-dialog.png'
 foreach($bad in @('x+z=0','x=y=2','sin(x=0')){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1423),$bad);[MathomirUiProbe]::Send($d,273,1439)|Out-Null;Check (![RelationProbe]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) "Invalid relation accepted: $bad"}
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1423),"x^2+y^2=25`r`nx*y=1`r`ny=x");[MathomirUiProbe]::Send($d,273,1439)|Out-Null
 Check ([RelationProbe]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) 'Mixed relations invalid';Apply $d;Place;$saved=SaveDoc
 Check ($saved.SelectNodes('//opr[@s="="] | //elm[@tp="2"][@stp="="]').Count -ge 3) 'Equations not native editable math'
 Check ([MathomirUiProbe]::CountColor($view,160,105,520,385,0) -gt 300) 'Native circle absent'
 Check ([MathomirUiProbe]::CountColor($view,160,105,520,385,0x0000CC00) -gt 150) 'Native hyperbola absent'
 Capture $main 'relation-equations-canvas.png'
 # Reopen a distinct copy, then edit the same graph with its shared editor.
 $reopened=Join-Path $folder 'relation-reopened.mom';Copy-Item $fixture $reopened;[MathomirUiProbe]::OpenFile($main,$reopened);$script:fixture=$reopened;Start-Sleep -Seconds 2;HoverGraph;$d=Dialog
 $text=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1423));Check ($text.Contains('y') -and $text.Contains('25') -and $text.Contains('=1')) "Saved relations lost: $text"
 [MathomirUiProbe]::Send($d,273,1437)|Out-Null;Apply $d;Start-Sleep -Seconds 2;$saved=SaveDoc
 Check ($saved.mathomir.ChildNodes.Count -eq 1) 'Editing duplicated graph'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$saved=SaveDoc;Check ($saved.SelectNodes('//opr[@s="="] | //elm[@tp="2"][@stp="="]').Count -ge 3) 'Undo did not restore relations'
 Blank 'parametric';$d=Dialog;[MathomirUiProbe]::Send($d,273,1438)|Out-Null
 Check ([RelationProbe]::IsWindowEnabled([MathomirUiProbe]::Child($d,1425))) 'Parametric fields disabled'
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1429),'0');[MathomirUiProbe]::Send($d,273,1439)|Out-Null;Check (![RelationProbe]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) 'Empty t interval accepted'
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1429),'2*pi');[MathomirUiProbe]::Send($d,273,1439)|Out-Null;Capture $d 'relation-parametric-dialog.png';Apply $d;Place;$saved=SaveDoc
 $metadata=$saved.SelectSingleNode('//parametric');Check ($metadata -and $metadata.rad -eq '1' -and [double]$metadata.hi -gt 6) 'Parametric metadata missing'
 Check ([MathomirUiProbe]::CountColor($view,160,105,520,385,0) -gt 200) 'Native parametric ellipse absent';Capture $main 'relation-parametric-canvas.png'
 HoverGraph;$before=Get-GraphRange $saved;[MathomirUiProbe]::Send($main,273,33030)|Out-Null;Start-Sleep -Seconds 1;$zoom=SaveDoc;$range=Get-GraphRange $zoom
 Check ([Math]::Abs(($range[1]-$range[0])/($before[1]-$before[0])-.8) -lt .001) 'Parametric zoom did not use existing graph window'
 HoverGraph;[MathomirUiProbe]::Send($main,273,33028)|Out-Null;Start-Sleep -Seconds 1;$fitted=SaveDoc;$range=Get-GraphRange $fitted
 Check ($range[0] -lt -3 -and $range[1] -gt 3 -and $range[1] -lt 5 -and $range[2] -lt -2 -and $range[3] -gt 2 -and $range[3] -lt 4) "Parametric fit failed: $range"

 $reopened=Join-Path $folder 'relation-parametric-reopened.mom';Copy-Item $fixture $reopened;[MathomirUiProbe]::OpenFile($main,$reopened);$script:fixture=$reopened;Start-Sleep -Seconds 2;HoverGraph;$d=Dialog
 Check ([MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1420),327,0) -eq 1) 'Parametric mode not reopened'
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1425)) -eq '3*cos(t)') 'x(t) changed on reopen'
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1425),'4*cos(t)');Apply $d;Start-Sleep -Seconds 2;$saved=SaveDoc;Check ($saved.mathomir.ChildNodes.Count -eq 1) 'Parametric edit duplicated graph'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$saved=SaveDoc;Check ($saved.SelectSingleNode('//parametric').x -eq $metadata.x) 'Parametric Undo failed'
 HoverGraph;$d=Dialog;$long=('0+'*80)+'3*cos(t)';[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1425),$long);Apply $d;Start-Sleep -Seconds 1;$saved=SaveDoc
 Check ($saved.SelectSingleNode('//parametric').x.Length -gt 320) 'Long formula not stored'
 $longFile=Join-Path $folder 'relation-long-parametric.mom';Copy-Item $fixture $longFile;[MathomirUiProbe]::OpenFile($main,$longFile);Start-Sleep -Seconds 2;HoverGraph;$d=Dialog
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1425)) -eq $long) 'Long parametric formula truncated on reopen';[MathomirUiProbe]::Send($d,273,2)|Out-Null
 Write-Output 'Native relation and parametric graph checks passed: previews, validation, mixed slots, rendered ink, persistence, edit and Undo.'
}catch{if($main -ne [IntPtr]::Zero){Capture $main 'relation-failure.png'};throw}finally{if($app -and !$app.HasExited){Stop-Process -Id $app.Id -Force};Remove-Item Env:MATHOMIR_GRAPH_DIAGNOSTICS -ErrorAction SilentlyContinue}
