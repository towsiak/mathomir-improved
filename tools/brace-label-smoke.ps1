$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BraceUI {
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int n);
 [DllImport("user32.dll")] static extern IntPtr GetPropA(IntPtr h,string key);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h,ref Point p);
 [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
 [StructLayout(LayoutKind.Sequential)] struct Point {public int x,y;}
 public static int Stat(IntPtr h,string key){return GetPropA(h,"MathomirLayer_"+key).ToInt32()-1;}
 public static void Drag(IntPtr frame,IntPtr view,int x,int y,int endX,int endY){SetForegroundWindow(frame);Point a=new Point{x=x,y=y},b=new Point{x=endX,y=endY};ClientToScreen(view,ref a);ClientToScreen(view,ref b);SetCursorPos(a.x,a.y);System.Threading.Thread.Sleep(100);mouse_event(2,0,0,0,UIntPtr.Zero);System.Threading.Thread.Sleep(80);try{for(int i=1;i<=4;i++){SetCursorPos(a.x+(b.x-a.x)*i/4,a.y+(b.y-a.y)*i/4);System.Threading.Thread.Sleep(60);}}finally{mouse_event(4,0,0,0,UIntPtr.Zero);}System.Threading.Thread.Sleep(160);}
}
'@
function Check($ok,$why){if(!$ok){throw $why}}
function Capture($h,$name){$r=[MathomirUiProbe]::WindowRect($h);$b=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[Drawing.Graphics]::FromImage($b);try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size);$b.Save((Join-Path $folder $name))}finally{$g.Dispose();$b.Dispose()}}
function Offset($n){if($n.HasAttribute('d')){$p=$n.d.Split(';')[0].Split(',');return @(([double]$p[0]/32),([double]$p[1]/32))};return @(([double]$n.X1/1000),([double]$n.Y1/1000))}
function Root($doc){return $doc.mathomir.ChildNodes[0]}
function Part($doc,$i){$root=Root $doc;$node=$root.SelectNodes('./gr | ./group')[$i];$offset=Offset $node;$last=$null;return @(foreach($point in (ShaderPoints $node)){if($last -and [Math]::Abs($point.x-$last.x) -lt .001 -and [Math]::Abs($point.y-$last.y) -lt .001){continue};$last=$point;[pscustomobject]@{x=[double]$root.X+$offset[0]+$point.x;y=[double]$root.Y+$offset[1]+$point.y}})}
function BoxCenter($doc){$p=Part $doc 2;return @((($p[0].x+$p[2].x)/2),(($p[0].y+$p[2].y)/2))}
function Joined($doc){$p=Part $doc 0;$line=Part $doc 1;Check ($p.Count -eq 11 -and $line.Count -eq 2) 'Brace or connector has wrong native geometry';Check ([Math]::Abs($p[5].x-$line[0].x) -le 2 -and [Math]::Abs($p[5].y-$line[0].y) -le 2) 'Label detached from the actual middle tip'}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $fixture -Raw)}
function Hover($doc){$p=Part $doc 0;[MathomirUiProbe]::Mouse($view,512,0,[int]$p[1].x,[int]$p[1].y);[MathomirUiProbe]::Send($view,(0x8000+156),4)|Out-Null;Start-Sleep -Milliseconds 100}
function Dialog {
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33107,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($app.Id,'Brace with label box');if($d -ne [IntPtr]::Zero){return $d}};throw 'Brace-label dialog did not open'
}
function DoubleClick($x,$y){[MathomirUiProbe]::Mouse($view,512,0,$x,$y);[MathomirUiProbe]::Mouse($view,513,1,$x,$y);[MathomirUiProbe]::Mouse($view,514,0,$x,$y);[MathomirUiProbe]::Mouse($view,515,1,$x,$y);[MathomirUiProbe]::Mouse($view,514,0,$x,$y)}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe
$env:MATHOMIR_PLACEMENT_DIAGNOSTICS='1';$env:MATHOMIR_DIAGNOSTIC_STARTUP='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start';[BraceUI]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 foreach($side in 0..3){
  $script:fixture=Join-Path $folder ("brace-label-$side.mom");'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $fixture -Encoding ascii;[MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200
  [MathomirUiProbe]::Send($view,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
  $d=Dialog;Check ([MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1441),326,0) -eq 4) 'Four brace orientations missing'
  if($side -eq 0){foreach($bad in @('0','1201','wrong')){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1442),$bad);Check (![MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) "Invalid brace length accepted: $bad"};[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1442),'240')}
  [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1440),'Part A');[MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1441),334,$side)|Out-Null;[MathomirUiProbe]::Send($d,273,((1-shl 16)-bor 1441))|Out-Null
  Check ([MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) 'Valid brace disabled';Capture $d "brace-label-dialog-$side.png"
  [MathomirUiProbe]::PostMessage($d,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 350
  [MathomirUiProbe]::Mouse($view,512,0,150,150);Start-Sleep -Milliseconds 150;Capture $main "brace-label-carry-$side.png"
  [MathomirUiProbe]::Mouse($view,513,1,150,150);[MathomirUiProbe]::Mouse($view,514,0,150,150);[MathomirUiProbe]::Send($view,258,27)|Out-Null
  $before=SaveDoc;Check ($before.mathomir.ChildNodes.Count -eq 1 -and (Root $before).SelectSingleNode('./bracelabel')) 'Brace and label were not placed as one attached object';Joined $before
  Check ((Root $before).SelectNodes('./gr | ./group').Count -eq 3 -and (Root $before).SelectNodes('./subexp').Count -eq 1) 'Native box, connector or editable label missing'
  $p=Part $before 0;$center=BoxCenter $before;$tip=$p[5];$nx=@(0,0,1,-1)[$side];$ny=@(1,-1,0,0)[$side]
  Check (($center[0]-$tip.x)*$nx+($center[1]-$tip.y)*$ny -gt 0) 'Label is on the wrong side of the brace';Capture $main "brace-label-placed-$side.png"
  # Both move grips and the normal resize grip act on the whole native group.
  Hover $before;$gx=[BraceUI]::Stat($view,'CenterX');$gy=[BraceUI]::Stat($view,'CenterY');Check ($gx -ge 0) 'Brace has no center move grip'
  [BraceUI]::Drag($main,$view,$gx,$gy,($gx+35),($gy+25));$moved=SaveDoc;Joined $moved
  $dx=[double](Root $moved).X-[double](Root $before).X;$dy=[double](Root $moved).Y-[double](Root $before).Y;Check ([Math]::Abs($dx)+[Math]::Abs($dy) -gt 10) 'Center grip did not move the brace'
  foreach($part in 0..2){$a=Part $before $part;$b=Part $moved $part;Check ([Math]::Abs(($b[0].x-$a[0].x)-$dx) -lt 1 -and [Math]::Abs(($b[0].y-$a[0].y)-$dy) -lt 1) 'Move separated an annotation component'}
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$undo=SaveDoc;Check ((Root $undo).X -eq (Root $before).X -and (Root $undo).Y -eq (Root $before).Y) 'Undo did not restore brace position'
  Hover $undo;$size=[MathomirUiProbe]::SizeGrip($view);[BraceUI]::Drag($main,$view,$size[0],$size[1],($size[0]+40),($size[1]+30));$resized=SaveDoc;Joined $resized
  Check ((Root $resized).SelectSingleNode('./bracelabel')) 'Resize discarded attachment metadata'
  # Double-clicking the actual box edits its embedded label without a new object.
  $center=BoxCenter $resized;$anchor=(Part $resized 0)[5];$boxBefore=Part $resized 2
  DoubleClick ([int]$center[0]) ([int]$center[1]);[MathomirUiProbe]::Send($view,256,0x23)|Out-Null
  foreach($c in ' extended label across the brace'.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$c)|Out-Null};[MathomirUiProbe]::Send($view,258,27)|Out-Null
  $edited=SaveDoc;Joined $edited;Check ($edited.mathomir.ChildNodes.Count -eq 1 -and (Root $edited).OuterXml.Contains('extended')) 'Editing created a separate object or lost the label'
  $newAnchor=(Part $edited 0)[5];Check ([Math]::Abs($newAnchor.x-$anchor.x) -le 2 -and [Math]::Abs($newAnchor.y-$anchor.y) -le 2) 'Typing moved the brace tip'
  $boxAfter=Part $edited 2;Check ([Math]::Abs($boxAfter[1].x-$boxAfter[0].x) -gt [Math]::Abs($boxBefore[1].x-$boxBefore[0].x)+20) 'Box did not grow for a longer label'
  $reopened=Join-Path $folder ("brace-label-reopened-$side.mom");Copy-Item $fixture $reopened;[MathomirUiProbe]::OpenFile($main,$reopened);$script:fixture=$reopened;Start-Sleep -Milliseconds 250;$restored=SaveDoc;Joined $restored;Check ((Root $restored).SelectSingleNode('./bracelabel') -and (Root $restored).OuterXml.Contains('extended')) 'Save/reopen lost the attached label'
  # Center-grip editing remains available even for a small or crowded label.
  Hover $restored;$gx=[BraceUI]::Stat($view,'CenterX');$gy=[BraceUI]::Stat($view,'CenterY');DoubleClick $gx $gy;[MathomirUiProbe]::Send($view,256,0x23)|Out-Null;[MathomirUiProbe]::Send($view,258,[int][char]'!')|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null;$final=SaveDoc
  Check ($final.mathomir.ChildNodes.Count -eq 1 -and (Root $final).OuterXml.Contains('!')) 'Center grip did not edit the existing label';Joined $final;Capture $main "brace-label-edited-$side.png"
  Write-Output "Brace label ${side}: native placement, connector, movement, Undo, resize, double-click edits, live box reflow and persistence passed."
 }
}catch{if($main -ne [IntPtr]::Zero){Capture $main 'brace-label-failure.png'};throw}finally{if($app -and !$app.HasExited){Stop-Process -Id $app.Id -Force};Remove-Item Env:MATHOMIR_PLACEMENT_DIAGNOSTICS -ErrorAction SilentlyContinue;Remove-Item Env:MATHOMIR_DIAGNOSTIC_STARTUP -ErrorAction SilentlyContinue}
