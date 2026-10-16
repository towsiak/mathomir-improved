$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
$all=Get-Content (Join-Path $PSScriptRoot 'placement-preview-smoke.ps1') -Raw
$start=$all.IndexOf('Add-Type -AssemblyName System.Drawing')
Invoke-Expression $all.Substring($start,$all.IndexOf('$exe=(Resolve-Path')-$start)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PaletteProbe {
 [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,IntPtr l,uint flags,uint ms,out UIntPtr result);
 public static int Query(IntPtr h,int kind,int index){UIntPtr result;if(SendMessageTimeout(h,0x8000+156,(IntPtr)kind,(IntPtr)index,2,5000,out result)==IntPtr.Zero)throw new Exception("Palette did not respond");return unchecked((int)result.ToUInt64());}
 public static int Ink(int[] pixels,int width,int height,int left,int top,int right,int bottom){int count=0;for(int y=Math.Max(0,top);y<Math.Min(height,bottom);y++)for(int x=Math.Max(0,left);x<Math.Min(width,right);x++){int c=pixels[y*width+x];if((c&255)<180&&((c>>8)&255)<180&&((c>>16)&255)<180)count++;}return count;}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path;$folder=Split-Path $exe
$env:MATHOMIR_PLACEMENT_DIAGNOSTICS='1';$app=Start-Process $exe -WorkingDirectory $folder -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function MovePointer($x,$y){[MathomirUiProbe]::Mouse($view,512,0,$x,$y)}
function Cancel {[MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null;MovePointer 25 20;[PlacementProbe]::Refresh($view)}
function Snapshot {return [PlacementProbe]::Capture($view,$width,$height)}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $fixture -Raw)}
function AssertPreview($kind,$index){
 [PlacementProbe]::Refresh($view)
 Check ([PlacementProbe]::Stat($view,'Active') -eq 1) "No in-transit preview: index=$index kind=$kind"
 Check ([PlacementProbe]::Stat($view,'Kind') -eq $(if($kind -gt 100){4}else{1})) "Wrong preview route: index=$index kind=$kind"
 $left=[PlacementProbe]::Stat($view,'Left');$top=[PlacementProbe]::Stat($view,'Top');$right=[PlacementProbe]::Stat($view,'Right');$bottom=[PlacementProbe]::Stat($view,'Bottom')
 $shot=Snapshot
 try{Check ([PaletteProbe]::Ink($shot.Pixels,$shot.Width,$shot.Height,$left,$top,$right,$bottom) -gt 0) "Preview has no object ink: index=$index kind=$kind"}finally{$shot.Dispose()}
}
function SaveShot($image,$name){
 $bitmap=New-Object System.Drawing.Bitmap $image.Width,$image.Height;$rect=New-Object System.Drawing.Rectangle 0,0,$image.Width,$image.Height
 $bits=$bitmap.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
 try{[Runtime.InteropServices.Marshal]::Copy($image.Pixels,0,$bits.Scan0,$image.Pixels.Length)}finally{$bitmap.UnlockBits($bits)}
 try{$bitmap.Save((Join-Path $folder $name))}finally{$bitmap.Dispose()}
}
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'No application window'
 [PlacementProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 $client=[MathomirUiProbe]::ClientRect($view);$width=$client.Right;$height=$client.Bottom
 $fixture=Join-Path $folder 'palette-carry-baseline.mom'
 '<?xml version="1.0"?><mathomir><o t="1" X="40" Y="60"><ex><var t="seed" f="00" /></ex></o></mathomir>'|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200
 [MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
 MovePointer 25 20;$baseline=SaveDoc
 $count=[PaletteProbe]::Query($view,5,-1);Check ($count -gt 100) 'Palette enumeration incomplete'
 $tools=New-Object System.Collections.Generic.List[int];$mathCount=0;$toolCount=0
 foreach($zoom in @(100,60,200)){
  [MathomirUiProbe]::Send($view,273,$(if($zoom -eq 60){32777}elseif($zoom -eq 200){33019}else{32775}))|Out-Null
  MovePointer 25 20;[PlacementProbe]::Refresh($view);$clean=Snapshot
  for($index=0;$index -lt $count;$index++){
   $kind=[PaletteProbe]::Query($view,5,$index)
   if($kind -eq 0 -or $kind -eq 2){continue}
   if($zoom -ne 100 -and $kind -le 100){continue}
   Check ([PaletteProbe]::Query($view,6,$index) -eq $kind) "Actual palette pickup failed: $index"
   MovePointer 320 220;AssertPreview $kind $index
   MovePointer 350 245;AssertPreview $kind $index
   if($kind -eq 130 -and $zoom -eq 100){$s=Snapshot;SaveShot $s 'palette-carry-triangle.png';$s.Dispose()}
   if($kind -gt 100){$toolCount++;if($zoom -eq 100){$tools.Add($index)}}else{$mathCount++}
   Cancel
   Check ([PlacementProbe]::Stat($view,'Active') -ne 1) "Escape left preview for $index"
   if($kind -gt 100){Check ([PaletteProbe]::Query($view,7,0) -eq 0) 'Escape left drawing tool active'}
  }
  Check ((SaveDoc).OuterXml -eq $baseline.OuterXml) 'Picking up/carrying palette items changed the document'
  $after=Snapshot;try{$difference=[PlacementProbe]::Compare($clean,$after,0,0,$width,$height);Check ($difference[1] -le 3) 'Cancelled palette previews left canvas ink'}finally{$clean.Dispose();$after.Dispose()}
 }
 # Actual left-side click: first default operator tile, before any board click.
 $toolbox=[MathomirUiProbe]::CaptionChild($main,'Toolbox');$tr=[MathomirUiProbe]::ClientRect($toolbox);$tile=[int]($tr.Right/4);$tileY=[int]($tr.Right/2+6)
 [MathomirUiProbe]::Mouse($toolbox,512,0,$tile,$tileY);[MathomirUiProbe]::Mouse($toolbox,513,1,$tile,$tileY);[MathomirUiProbe]::Mouse($toolbox,514,0,$tile,$tileY)
 MovePointer 320 220;AssertPreview 1 -1;Cancel
 # A real drawing gesture must keep its shape; samples never touch creator state.
 foreach($index in $tools){
  $kind=[PaletteProbe]::Query($view,5,$index);$form=$kind-100
  if($form -notin @(1,2,4,5,8,9,15,16,17,19,27,28,29,30,31,32,33)){continue}
  [MathomirUiProbe]::Send($view,273,32775)|Out-Null
  [PaletteProbe]::Query($view,6,$index)|Out-Null;MovePointer 320 220;AssertPreview $kind $index
  [MathomirUiProbe]::Mouse($view,513,1,320,220)
  for($step=1;$step -le 4;$step++){[MathomirUiProbe]::Mouse($view,512,1,(320+25*$step),(220+20*$step))}
  [MathomirUiProbe]::Mouse($view,514,0,420,300)
  $placed=SaveDoc;Check ($placed.mathomir.ChildNodes.Count -eq 2) "Drawing sample changed or consumed placement: form=$form"
  $drawing=$placed.SelectSingleNode('/mathomir/*[@t="2" or @type="2"]');Check ($null -ne $drawing) "Palette tool placed no native drawing: form=$form"
  Cancel;[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;Check ((SaveDoc).OuterXml -eq $baseline.OuterXml) "Palette drawing Undo failed: form=$form"
 }
 Write-Output "Palette carry passed: $mathCount native math entries; $toolCount drawing-tool previews across 100/60/200 percent; actual left tile click; moving previews, visible native ink, Escape cleanup, unchanged document, native drawing gestures and Undo."
}catch{try{$s=Snapshot;SaveShot $s 'palette-carry-failure.png';$s.Dispose();$null=SaveDoc}catch{};throw}finally{if($app -and !$app.HasExited){$app.Kill();$app.WaitForExit()};Remove-Item Env:MATHOMIR_PLACEMENT_DIAGNOSTICS -ErrorAction SilentlyContinue}
