$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RotationPivotProbe {
 [DllImport("user32.dll",CharSet=CharSet.Ansi)] static extern IntPtr GetPropA(IntPtr h,string key);
 public static int Stat(IntPtr h,string key){return GetPropA(h,"RotationPivot_"+key).ToInt32()-1;}
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int command);
 [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int width,int height,uint flags);
 public static void MovePopup(IntPtr h){SetWindowPos(h,IntPtr.Zero,650,80,0,0,0x15);}
 [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr h,IntPtr rect,IntPtr region,uint flags);
 public static void Refresh(IntPtr h){RedrawWindow(h,IntPtr.Zero,IntPtr.Zero,0x121);}
}
'@
function Check($ok,$why){if(!$ok){throw $why}}
function Stat($name){return [RotationPivotProbe]::Stat($view,$name)}
function MovePointer($x,$y){[MathomirUiProbe]::Mouse($view,512,0,$x,$y);[RotationPivotProbe]::Refresh($view)}
function Capture($name){
 $r=[MathomirUiProbe]::WindowRect($view);$b=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[Drawing.Graphics]::FromImage($b)
 try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size);$b.Save((Join-Path $folder $name))}finally{$g.Dispose();$b.Dispose()}
}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $fixture -Raw)}
function Marker($x,$y){
 Check ((Stat 'Visible') -eq 1) 'Rotation center overlay missing'
 Check ([Math]::Abs((Stat 'X')-$x) -le 2 -and [Math]::Abs((Stat 'Y')-$y) -le 2) "Wrong pivot: expected $x,$y; got $(Stat 'X'),$(Stat 'Y')"
 Check ([MathomirUiProbe]::CountColor($view,(Stat 'X')-9,(Stat 'Y')-9,19,19,0x5A3714) -gt 15) 'Rotation center has no visible native crosshair/dot'
}
function Scene($name,$objects,$zoom=100){
 $script:fixture=Join-Path $folder ("rotation-center-$name.mom");('<?xml version="1.0"?><mathomir>'+$objects+'</mathomir>')|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 150
 [MathomirUiProbe]::Send($view,273,$(if($zoom -eq 60){32777}elseif($zoom -eq 200){33019}else{32775}))|Out-Null
 [MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
 $script:scale=$zoom/100.0;MovePointer 700 430
}
function Grip($x,$y){
 MovePointer ([int]($x*$scale)) ([int]($y*$scale));[MathomirUiProbe]::Send($main,273,33008)|Out-Null
 [RotationPivotProbe]::Refresh($view);$g=@((Stat 'GripX'),(Stat 'GripY'))
 Check ($g[0] -ge 0 -and $g[1] -ge 0) 'No native rotation grip'
 MovePointer $g[0] $g[1];return $g
}
function PopupOption($data){
 $rows=@(Get-Content (Join-Path $folder 'popup-colors-menu.txt')|ForEach-Object{($_ -split ' ',5)})
 # Read one row without PowerShell flattening the parsed columns.
 foreach($row in Get-Content (Join-Path $folder 'popup-colors-menu.txt')){$v=$row -split ' ',5;if([int]$v[0] -eq $data){return @([int]$v[1],[int]$v[2])}}
 throw "Rotation popup option $data missing"
}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe
$env:MATHOMIR_ROTATION_DIAGNOSTICS='1';$env:MATHOMIR_POPUP_COLOR_DIAGNOSTICS='1';$env:MATHOMIR_DIAGNOSTIC_STARTUP='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start'
 [RotationPivotProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 $triangle='<dw d="32|0,0;3840,0;2560,2560;0,0" />'
 $shape='<o t="2" X="180" Y="180">'+$triangle+'</o>'
 $filled='<o t="2" X="180" Y="180"><dw t="91" d="32|0,0;3840,0;2560,2560;0,0" /></o>'
 $group='<o t="2" X="180" Y="180"><gr d="0,0;3840,2560">'+$triangle+'</gr></o>'
 foreach($kind in @('shape','filled','group')){foreach($zoom in @(60,100,200)){
  Scene "$kind-$zoom" $(if($kind -eq 'filled'){$filled}elseif($kind -eq 'group'){$group}else{$shape}) $zoom
  $baseline=(SaveDoc).OuterXml;$g=Grip 210 180
  Marker ([int](241*$scale)) ([int](221*$scale));$pivot=@((Stat 'X'),(Stat 'Y'))
  Check ((SaveDoc).OuterXml -eq $baseline) 'Hovering the rotation grip changed the document'
  [MathomirUiProbe]::Mouse($view,513,1,$g[0],$g[1]);Marker $pivot[0] $pivot[1]
  for($step=1;$step -le 4;$step++){
   [MathomirUiProbe]::Mouse($view,512,1,[int]($g[0]+($pivot[0]-$g[0])*$step/4),[int]($g[1]+($pivot[1]+80-$g[1])*$step/4));Marker $pivot[0] $pivot[1]
  }
  if($zoom -eq 100){Capture "rotation-center-$kind-drag.png"}
  [MathomirUiProbe]::Mouse($view,514,0,$pivot[0],($pivot[1]+80));MovePointer 700 430
  Check ((Stat 'Visible') -eq 0) 'Rotation marker stuck after releasing the grip'
  $rotated=SaveDoc;Check ($rotated.OuterXml -ne $baseline) 'Drawing did not rotate'
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;MovePointer 700 430;Check ((SaveDoc).OuterXml -eq $baseline) 'Rotation Undo changed geometry'
  $g=Grip 210 180;[MathomirUiProbe]::Mouse($view,513,1,$g[0],$g[1]);[MathomirUiProbe]::Mouse($view,512,1,($g[0]-40),($g[1]+60));[MathomirUiProbe]::Send($view,256,27)|Out-Null
  MovePointer 700 430;Check ((Stat 'Visible') -eq 0) 'Escape left a rotation marker';Check ((SaveDoc).OuterXml -eq $baseline) 'Rotation Escape changed geometry'
  Write-Output "Rotation pivot passed: $kind, zoom=$zoom, hover point, stationary drag pivot, visible ink, release, Undo, Escape, unchanged hover document"
 }}
 # A selection uses a common pivot; angle buttons preview that same pivot.
 $second='<o t="2" X="380" Y="240"><dw d="32|0,0;2560,0;2560,2560;0,2560;0,0" /></o>'
 Scene 'selection' ($shape+$second);$baseline=(SaveDoc).OuterXml
 [MathomirUiProbe]::Send($view,273,0xE12A)|Out-Null
 MovePointer 210 180;[MathomirUiProbe]::Mouse($view,516,2,210,180);[MathomirUiProbe]::Mouse($view,517,0,210,180)
 $popup=[MathomirUiProbe]::Window($app.Id,'PopupMenu');Check ($popup -ne [IntPtr]::Zero) 'Selection popup missing';[RotationPivotProbe]::MovePopup($popup)
 $option=PopupOption 541;[MathomirUiProbe]::Mouse($popup,512,0,$option[0],$option[1]);Marker 321 251
 Check ((SaveDoc).OuterXml -eq $baseline) 'Popup pivot preview changed selection'
 Capture 'rotation-center-selection-popup.png'
 [MathomirUiProbe]::Mouse($popup,513,1,$option[0],$option[1]);[RotationPivotProbe]::Refresh($view);Marker 321 251
 Start-Sleep -Milliseconds 1700;[RotationPivotProbe]::Refresh($view);Check ((Stat 'Visible') -eq 0) 'Popup rotation pivot did not clear after its brief display'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;Check ((SaveDoc).OuterXml -eq $baseline) 'Popup rotation Undo changed geometry'
 # Legacy selection right-drag starts on its top-left stretch handle.
 MovePointer 177 177;[MathomirUiProbe]::Mouse($view,516,2,177,177);Marker 321 251
 [MathomirUiProbe]::Mouse($view,512,2,300,130);Marker 321 251;Capture 'rotation-center-selection-drag.png'
 [MathomirUiProbe]::Mouse($view,517,0,300,130);MovePointer 700 430;Check ((Stat 'Visible') -eq 0) 'Selection right-drag left its pivot marker'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;Check ((SaveDoc).OuterXml -eq $baseline) 'Selection rotation Undo changed geometry'
 Write-Output 'Rotation center passed: shared selection pivot, popup hover/action/expiry, right-drag selection, Undo, no serialized marker.'
}catch{
 $failure=$_;try{Capture 'rotation-center-failure.png'}catch{};throw $failure
}finally{
 if(!$app.HasExited){Stop-Process -Id $app.Id -Force}
 Remove-Item Env:MATHOMIR_ROTATION_DIAGNOSTICS -ErrorAction SilentlyContinue
 Remove-Item Env:MATHOMIR_POPUP_COLOR_DIAGNOSTICS -ErrorAction SilentlyContinue
}
