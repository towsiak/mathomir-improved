$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ObjectPointerProbe {
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int command);
 [DllImport("user32.dll")] static extern IntPtr GetPropA(IntPtr h,string key);
 public static int Stat(IntPtr h,string key){return GetPropA(h,"MathomirLayer_"+key).ToInt32()-1;}
}
'@
function Check($ok,$why){if(!$ok){throw $why}}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $fixture -Raw)}
function Capture($h,$name){$r=[MathomirUiProbe]::WindowRect($h);$b=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[Drawing.Graphics]::FromImage($b);try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size);$b.Save((Join-Path $folder $name))}finally{$g.Dispose();$b.Dispose()}}
function Offset($node){if($node.HasAttribute('d')){$p=$node.d.Split(';')[0].Split(',');return @(([double]$p[0]/32),([double]$p[1]/32))};return @(([double]$node.X1/1000),([double]$node.Y1/1000))}
function Root($doc){return $doc.mathomir.ChildNodes[0]}
function Pointer($doc){return (Root $doc).SelectSingleNode('./pointer')}
function OpenPopup {
 $x=if($kind -in @('shape','group')){200}else{188};$y=if($kind -in @('shape','group')){160}else{174}
 [MathomirUiProbe]::Mouse($view,512,0,$x,$y);[MathomirUiProbe]::Mouse($view,516,2,$x,$y);[MathomirUiProbe]::Mouse($view,517,0,$x,$y)
 Start-Sleep -Milliseconds 100;$script:popup=[MathomirUiProbe]::Window($app.Id,'PopupMenu');Check ($popup -ne [IntPtr]::Zero) "No pointer popup for $kind"
}
function Choose($data){
 $found=$false
 foreach($row in Get-Content (Join-Path $folder 'popup-colors-menu.txt')){$p=$row -split ' ',5;if([int]$p[0] -eq $data){$x=[int]$p[1];$y=[int]$p[2];$found=$true;break}}
 Check $found "Pointer option $data missing"
 [MathomirUiProbe]::Mouse($popup,512,0,$x,$y);[MathomirUiProbe]::Mouse($popup,513,1,$x,$y);Start-Sleep -Milliseconds 70
}
function ArrowPoints($doc){
 $root=Root $doc;$arrow=$root.SelectSingleNode('./gr[last()] | ./group[last()]');$off=Offset $arrow
 $points=@(ShaderPoints $arrow)
 return @($points|ForEach-Object{[pscustomobject]@{x=[double]$root.X+$off[0]+$_.x;y=[double]$root.Y+$off[1]+$_.y}})
}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe
$env:MATHOMIR_POPUP_COLOR_DIAGNOSTICS='1';$env:MATHOMIR_PLACEMENT_DIAGNOSTICS='1';$env:MATHOMIR_DIAGNOSTIC_STARTUP='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start';[ObjectPointerProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 $box='<dw d="32|0,0;3840,0;3840,2560;0,2560;0,0" />'
 $neighbor='<o t="1" X="520" Y="180"><ex><var t="neighbor" f="00" /></ex></o>'
 foreach($kind in @('text','math','shape','group')){
  $body=switch($kind){text {'<o t="1" X="180" Y="180"><ex fh="160" stxt="1" bg="11270399"><var t="A" f="00" /></ex></o>'} math {'<o t="1" X="180" Y="180"><ex fh="160"><var t="x" f="00" /><opr s="=" /><var t="2" f="00" /></ex></o>'} shape {'<o t="2" X="180" Y="160">'+$box+'</o>'} group {'<o t="2" X="180" Y="160"><gr d="0,0;3840,2560">'+$box+'</gr></o>'}}
  $script:fixture=Join-Path $folder ("object-pointer-$kind.mom");('<?xml version="1.0"?><mathomir>'+$body+$neighbor+'</mathomir>')|Set-Content $fixture -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 150;[MathomirUiProbe]::Send($view,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
  $baseline=SaveDoc;$neighborXml=$baseline.mathomir.ChildNodes[1].OuterXml
  for($direction=1;$direction -le 8;$direction++){
   OpenPopup;if($direction -eq 1){Capture $popup "object-pointer-$kind-picker.png"};Choose (960+$direction);$saved=SaveDoc;$pointer=Pointer $saved
   Check ($pointer -and [int]$pointer.dir -eq $direction) "Pointer direction $direction not saved for $kind"
   Check ($saved.mathomir.ChildNodes.Count -eq 2 -and $saved.mathomir.ChildNodes[1].OuterXml -eq $neighborXml) 'Pointer altered a neighboring object'
   $points=ArrowPoints $saved;Check ($points.Count -ge 5) 'Attached arrow lacks native shaft and arrowhead'
   $tail=$points[0];$tip=$points[1];$dx=$tip.x-$tail.x;$dy=$tip.y-$tail.y
   $expectedX=@(0,1,1,1,0,-1,-1,-1)[$direction-1];$expectedY=@(-1,-1,0,1,1,1,0,-1)[$direction-1]
   Check ([Math]::Sign([Math]::Round($dx)) -eq $expectedX -and [Math]::Sign([Math]::Round($dy)) -eq $expectedY) "Wrong native arrow direction $direction for $kind"
   [MathomirUiProbe]::Mouse($view,512,0,700,430)
   Check ([MathomirUiProbe]::CountColor($view,[int]([Math]::Min($tail.x,$tip.x)-5),[int]([Math]::Min($tail.y,$tip.y)-5),[int]([Math]::Abs($dx)+11),[int]([Math]::Abs($dy)+11),0) -gt 10) 'Attached native pointer is not visible'
   OpenPopup;Choose 960;$removed=SaveDoc
   Check (!(Pointer $removed)) 'None left pointer metadata'
   Check ([Math]::Abs([double](Root $removed).X-180) -le 1 -and [Math]::Abs([double](Root $removed).Y-$(if($kind -in @('shape','group')){160}else{180})) -le 1) 'Adding/removing a pointer moved the original object'
  }
  OpenPopup;Choose 963
  foreach($size in @(969,970,971)){OpenPopup;Choose $size;$saved=SaveDoc;Check ([int](Pointer $saved).len -eq @(24,48,80)[$size-969]) 'Pointer length choice was not retained'}
  [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 150;$reopened=SaveDoc;Check ([int](Pointer $reopened).dir -eq 3 -and [int](Pointer $reopened).len -eq 80) 'Reopening lost the attached pointer'
  OpenPopup;Choose 960;[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$restored=SaveDoc;Check ([int](Pointer $restored).dir -eq 3) 'Undo did not restore the attached pointer'
  if($kind -eq 'text'){
   # Double-clicking its existing center grip edits the original embedded label.
   [MathomirUiProbe]::Mouse($view,512,0,188,174);[MathomirUiProbe]::Send($view,(0x8000+156),4)|Out-Null
   $gx=[ObjectPointerProbe]::Stat($view,'CenterX');$gy=[ObjectPointerProbe]::Stat($view,'CenterY');Check ($gx -ge 0) 'Attached label has no move/edit grip'
   [MathomirUiProbe]::Mouse($view,512,0,$gx,$gy);[MathomirUiProbe]::Mouse($view,513,1,$gx,$gy);[MathomirUiProbe]::Mouse($view,514,0,$gx,$gy);[MathomirUiProbe]::Mouse($view,515,1,$gx,$gy);[MathomirUiProbe]::Mouse($view,514,0,$gx,$gy)
   [MathomirUiProbe]::Send($view,256,0x23)|Out-Null;foreach($c in 'BC'.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$c)|Out-Null};[MathomirUiProbe]::Send($view,258,27)|Out-Null
   $edited=SaveDoc;Check ($edited.mathomir.ChildNodes.Count -eq 2 -and (Pointer $edited)) 'Editing detached the label or created another object'
   Check ((Root $edited).OuterXml.Contains('BC')) 'Existing attached label was not editable'
  }
  Capture $view "object-pointer-$kind-result.png"
  Write-Output "Object pointer passed: $kind, eight directions, three lengths, native visible arrows, None, anchor preservation, neighbor isolation, Undo and save/reopen"
 }
 Write-Output 'Attached object pointer chooser passed.'
}catch{$failure=$_;try{Capture $main 'object-pointer-failure.png'}catch{};throw $failure}finally{
 if(!$app.HasExited){Stop-Process -Id $app.Id -Force}
 Remove-Item Env:MATHOMIR_POPUP_COLOR_DIAGNOSTICS -ErrorAction SilentlyContinue
 Remove-Item Env:MATHOMIR_PLACEMENT_DIAGNOSTICS -ErrorAction SilentlyContinue
}
