$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class CenterGripProbe {
 [StructLayout(LayoutKind.Sequential)] struct BitmapInfo {public uint Size;public int Width,Height;public ushort Planes,BitCount;public uint Compression,SizeImage;public int XPels,YPels;public uint Used,Important;}
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int command);
 [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h,IntPtr d);
 [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr d);
 [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr d,int w,int h);
 [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr d,IntPtr o);
 [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
 [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr d);
 [DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr d,IntPtr bmp,uint start,uint lines,int[] data,ref BitmapInfo info,uint use);
 [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr d,int x,int y,int w,int h,IntPtr s,int sx,int sy,uint rop);
 public static int[][] Centers(IntPtr h,int w,int height){IntPtr screen=GetDC(h),target=CreateCompatibleDC(screen),bmp=CreateCompatibleBitmap(screen,w,height),old=SelectObject(target,bmp);try{BitBlt(target,0,0,w,height,screen,0,0,0x00CC0020);SelectObject(target,old);old=IntPtr.Zero;var info=new BitmapInfo{Size=40,Width=w,Height=-height,Planes=1,BitCount=32};var pixels=new int[w*height];if(GetDIBits(screen,bmp,0,(uint)height,pixels,ref info,0)==0)throw new Exception("Could not read canvas pixels");var found=new List<int[]>();for(int y=8;y<height-8;y++)for(int x=8;x<w-8;x++){if((pixels[y*w+x]&0xffffff)!=0x2d5f9b)continue;bool cross=true;for(int k=-6;k<=6;k++)if((pixels[y*w+x+k]&0xffffff)!=0x2d5f9b||(pixels[(y+k)*w+x]&0xffffff)!=0x2d5f9b){cross=false;break;}if(cross)found.Add(new[]{x,y});}found.Sort((a,b)=>a[0].CompareTo(b[0]));return found.ToArray();}finally{if(old!=IntPtr.Zero)SelectObject(target,old);DeleteObject(bmp);DeleteDC(target);ReleaseDC(h,screen);}}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path;$folder=Split-Path $exe
$env:MATHOMIR_GRAPH_DIAGNOSTICS="1"
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $script:fixture -Raw)}
function Label($d){return $d.SelectSingleNode('/mathomir/*[@t="1" or @type="1"]')}
function Drawing($d){return $d.SelectSingleNode('/mathomir/*[@t="2" or @type="2"]')}
function Scene($name,$objects,$zoom=100){
 $script:fixture=Join-Path $folder ('center-grip-'+$name+'.mom');('<?xml version="1.0"?><mathomir>'+$objects+'</mathomir>')|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 180;[CenterGripProbe]::ShowWindow($main,3)|Out-Null
 [MathomirUiProbe]::Send($view,273,$(if($zoom -eq 60){32777}elseif($zoom -eq 200){33019}else{32775}))|Out-Null
 [MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
 $script:scale=$zoom/100.0;Start-Sleep -Milliseconds 100
}
function Grip($x,$y){[MathomirUiProbe]::Mouse($view,512,0,[int]($x*$scale),[int]($y*$scale));Start-Sleep -Milliseconds 80;$r=[MathomirUiProbe]::ClientRect($view);$points=[CenterGripProbe]::Centers($view,$r.Right,$r.Bottom);Check ($points.Length -eq 3) ('Expected three move grips; found '+$points.Length);return ,$points[1]}
function Drag($p,$dx,$dy,[switch]$Cancel){[MathomirUiProbe]::Mouse($view,512,0,$p[0],$p[1]);[MathomirUiProbe]::Mouse($view,513,1,$p[0],$p[1]);[MathomirUiProbe]::Mouse($view,512,1,($p[0]+$dx),($p[1]+$dy));if($Cancel){[MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null};[MathomirUiProbe]::Mouse($view,514,0,($p[0]+$dx),($p[1]+$dy))}
function Double($p){[MathomirUiProbe]::Mouse($view,512,0,$p[0],$p[1]);[MathomirUiProbe]::Mouse($view,513,1,$p[0],$p[1]);[MathomirUiProbe]::Mouse($view,514,0,$p[0],$p[1]);[MathomirUiProbe]::Mouse($view,515,1,$p[0],$p[1]);[MathomirUiProbe]::Mouse($view,514,0,$p[0],$p[1])}
function Capture($name){$r=[MathomirUiProbe]::WindowRect($main);$im=New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[System.Drawing.Graphics]::FromImage($im);$g.CopyFromScreen($r.Left,$r.Top,0,0,$im.Size);$im.Save((Join-Path $folder $name));$g.Dispose();$im.Dispose()}
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'Application did not start';[MathomirUiProbe]::Send($main,274,0xF030)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 $bounds=@('-5','5','-5','5')|ForEach-Object{'<subexp d="0,0;2000,704"><ex fh="100"><var t="'+$_+'" f="00" /></ex></subexp>'}
 $graph='<o t="2" X="100" Y="100"><dw spec="51" d="32|32,32;12800,32;:,10240;32,:;:,32" />'+($bounds-join '')+'<subexp d="0,0;4000,1000"><ex fh="100"><var t="x" f="00" /></ex></subexp></o>'
 foreach($text in @($false,$true)){foreach($last in @($false,$true)){foreach($zoom in @(60,100,200)){
  Write-Output ("Center grip case: text="+$text+", graphLast="+$last+", zoom="+$zoom)
  $note='<o t="1" X="210" Y="220"><ex fh="160"'+$(if($text){' stxt="1"'}else{''})+'><var t="overlaynote" f="00" color="1" /></ex></o>'
  Scene "overlay-$text-$last-$zoom" $(if($last){$note+$graph}else{$graph+$note}) $zoom
  $initial=SaveDoc;$graphXml=(Drawing $initial).OuterXml;$g=Grip 225 212
  Drag $g ([int](30*$scale)) ([int](20*$scale));$d=SaveDoc;Check ((Label $d).X -eq '240' -and (Label $d).Y -eq '240') ('Center grip moved the wrong object or jumped: grip='+($g -join ',')+' XML='+$d.OuterXml);Check ((Drawing $d).OuterXml -eq $graphXml) 'Dragging a label changed its graph'
  # A click/jitter must not create a second Undo record or move the object.
  $g=Grip 255 232;Drag $g 2 1;$d=SaveDoc;Check ((Label $d).X -eq '240' -and (Label $d).Y -eq '240') 'A small click moved the object'
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$d=SaveDoc;Check ((Label $d).X -eq '210' -and (Label $d).Y -eq '220') 'Clicking the center consumed Undo'
  $g=Grip 225 212;Drag $g ([int](24*$scale)) ([int](15*$scale)) -Cancel;$d=SaveDoc;Check ((Label $d).X -eq '210' -and (Label $d).Y -eq '220') 'Escape did not cancel the center move'
  $g=Grip 225 212;Double $g;[MathomirUiProbe]::Send($view,258,[int][char]'Z')|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null;$d=SaveDoc
  Check ($d.mathomir.ChildNodes.Count -eq 2 -and (Drawing $d).OuterXml -eq $graphXml) 'Double-click created another object or edited the graph'
  $letters=((Label $d).SelectNodes('.//var | .//elm[@tp="1"]')|ForEach-Object{if($_.HasAttribute('t')){$_.t}else{$_.tx}})-join '';Check ($letters.Contains('Z')) ('Double-click did not enter the original text/math object: letters='+$letters+' XML='+$d.OuterXml)
 }}}
 # A graph grip must avoid an annotation occupying its exact center.
 $centerNote='<o t="1" X="290" Y="270"><ex fh="160" stxt="1"><var t="overlaynote" f="00" /></ex></o>'
 Scene 'blocked-center' ($graph+$centerNote);$baseline=SaveDoc;$noteXml=(Label $baseline).OuterXml;$g=Grip 130 170;Drag $g 30 20;$d=SaveDoc;Check ((Drawing $d).X -eq '130' -and (Drawing $d).Y -eq '120') 'An overlaid label stole the graph center grip';Check ((Label $d).OuterXml -eq $noteXml) 'Graph center movement changed the overlaid label'
 # Older annotations remain independently movable over enlarged text.
 foreach($last in @($false,$true)){
  $big='<o t="1" X="100" Y="220"><ex fh="500"><var t="MMMMMMMM" f="00" /></ex></o>'
  Write-Output ("Center grip case: text="+$text+", graphLast="+$last+", zoom="+$zoom)
  $note='<o t="1" X="210" Y="210"><ex fh="160" stxt="1"><var t="overlaynote" f="00" /></ex></o>'
  Scene ('large-text-'+$last) $(if($last){$note+$big}else{$big+$note});$before=SaveDoc;$rootXml=$before.SelectSingleNode('/mathomir/*[.//var[@t="MMMMMMMM"] or .//elm[@tx="MMMMMMMM"]]').OuterXml;$g=Grip 225 202;Drag $g 30 20;$d=SaveDoc;$small=$d.SelectSingleNode('/mathomir/*[.//var[@t="overlaynote"] or .//elm[@tx="overlaynote"]]');Check ($small.X -eq '240' -and $small.Y -eq '230') 'Enlarged text stole the label center grip';Check ($d.SelectSingleNode('/mathomir/*[.//var[@t="MMMMMMMM"] or .//elm[@tx="MMMMMMMM"]]').OuterXml -eq $rootXml) 'Moving the label altered enlarged text'
 }
 # Graph center movement must preserve its definitions and viewing bounds.
 Scene 'graph' $graph;$original=SaveDoc;$g=Grip 300 260;Capture 'center-move-grip-ui.png';Drag $g 35 25;$d=SaveDoc;Check ((Drawing $d).X -eq '135' -and (Drawing $d).Y -eq '125') 'Graph center drag did not move the graph';Check ((Get-GraphRange $d)-join ',' -eq '-5,5,-5,5') 'Center drag zoomed the graph'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$g=Grip 300 260;Double $g;[MathomirUiProbe]::Send($view,256,0x23)|Out-Null;[MathomirUiProbe]::Send($view,258,[int][char]'Z')|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null;$d=SaveDoc;Check ($d.mathomir.ChildNodes.Count -eq 1) 'Graph double-click created a canvas object';Check ((Drawing $d).OuterXml.Contains('Z')) 'Graph double-click did not enter its formula'
 # The middle of an unfilled shape is a valid move target, with native node editing on double-click.
 $shape='<o t="2" X="150" Y="160"><dw d="64|0,0;3200,0;6400,3200;1600,2400;0,0" /></o>'
 Scene 'shape' $shape;$shapeBaseline=(Drawing (SaveDoc)).OuterXml;$g=Grip 250 210;Drag $g 30 20;$d=SaveDoc;Check ((Drawing $d).X -eq '180' -and (Drawing $d).Y -eq '180') 'Hollow shape center move failed';[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$g=Grip 250 210;Double $g;[MathomirUiProbe]::Mouse($view,512,0,350,260);[MathomirUiProbe]::Mouse($view,513,1,350,260);[MathomirUiProbe]::Mouse($view,512,1,375,280);[MathomirUiProbe]::Mouse($view,514,0,375,280);$d=SaveDoc;Check ((Drawing $d).OuterXml -ne $shapeBaseline) 'Shape double-click did not enable node editing';$vertices=@(ShaderPoints (Drawing $d));Check (@($vertices|Where-Object{[math]::Abs($_.x-375)-lt .1 -and [math]::Abs($_.y-280)-lt .1}).Count -gt 0) 'The chosen node did not reach the pointer';Check (@($vertices|Where-Object{[math]::Abs($_.x-250)-lt .1 -and [math]::Abs($_.y-160)-lt .1}).Count -gt 0 -and @($vertices|Where-Object{[math]::Abs($_.x-200)-lt .1 -and [math]::Abs($_.y-235)-lt .1}).Count -gt 0) 'Editing a node resized unrelated vertices'
 Write-Output 'Center grips passed: text/math over graphs in both creation orders at 60/100/200 percent, no-jump clicks, Undo, Escape, exact object editing, unchanged graph bounds, graph formula entry, hollow shape dragging and node editing.'
}catch{Capture 'center-move-grip-failure.png';($_|Out-String)|Set-Content (Join-Path $folder 'center-move-grip-result.txt');throw}finally{if(!$app.HasExited){$app.Kill();$app.WaitForExit()}}
