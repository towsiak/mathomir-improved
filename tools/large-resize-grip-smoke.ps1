$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LargeGripProbe {
 [StructLayout(LayoutKind.Sequential)] struct BitmapInfo {public uint Size;public int Width,Height;public ushort Planes,BitCount;public uint Compression,SizeImage;public int XPels,YPels;public uint Used,Important;}
 [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
 [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc,int w,int h);
 [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc,IntPtr o);
 [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr dc,int x,int y,int w,int h,IntPtr source,int sx,int sy,uint op);
 [DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr dc,IntPtr bmp,uint start,uint lines,byte[] pixels,ref BitmapInfo info,uint usage);
 [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
 [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
 static bool Blue(byte[] p,int w,int x,int y){int i=(y*w+x)*4;return p[i]==155&&p[i+1]==95&&p[i+2]==45;}
 public static int[] Find(IntPtr h,int width,int height){return FindInternal(h,width,height,false);}
 public static int[] FindInk(IntPtr h,int width,int height){return FindInternal(h,width,height,true);}
 static int[] FindInternal(IntPtr h,int width,int height,bool ink){IntPtr dc=GetDC(h),mem=CreateCompatibleDC(dc),bmp=CreateCompatibleBitmap(dc,width,height),old=SelectObject(mem,bmp);try{
  BitBlt(mem,0,0,width,height,dc,0,0,0x00cc0020);SelectObject(mem,old);old=IntPtr.Zero;
  byte[] pixels=new byte[width*height*4];BitmapInfo info=new BitmapInfo{Size=40,Width=width,Height=-height,Planes=1,BitCount=32};
  if(GetDIBits(dc,bmp,0,(uint)height,pixels,ref info,0)==0)throw new Exception("Could not capture the canvas.");
  if(ink){for(int y=40;y<height-20;y++)for(int x=40;x<width-30;x++){int i=(y*width+x)*4;if(pixels[i]<30&&pixels[i+1]<30&&pixels[i+2]<30)return new int[]{x,y};}throw new Exception("No visible equation ink for hover.");}
  for(int y=8;y<height-12;y++)for(int x=8;x<width-12;x++){if(!Blue(pixels,width,x,y))continue;bool square=true;for(int k=0;k<13;k++)if(!Blue(pixels,width,x+k,y)||!Blue(pixels,width,x,y+k)||!Blue(pixels,width,x+12,y+k)){square=false;break;}if(square)return new int[]{x+6,y+6};}
  throw new Exception("Visible resize grip was not found.");
 }finally{if(old!=IntPtr.Zero)SelectObject(mem,old);DeleteObject(bmp);DeleteDC(mem);ReleaseDC(h,dc);}}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $script:fixture -Raw)}
function Font($doc){$e=$doc.SelectSingleNode('/mathomir/*[1]/*[self::ex or self::expr]');if($e.HasAttribute('fh')){return [int]$e.fh};return [int]$e.fnt_h}
function Grip {Start-Sleep -Milliseconds 70;$r=[MathomirUiProbe]::ClientRect($view);return [LargeGripProbe]::Find($view,$r.Right,$r.Bottom)}
function HoverObject {$r=[MathomirUiProbe]::ClientRect($view);$p=[LargeGripProbe]::FindInk($view,$r.Right,$r.Bottom);[MathomirUiProbe]::Mouse($view,512,0,$p[0],$p[1])}
function Drag($g,$dx,$dy,$release=$true){
 [MathomirUiProbe]::Mouse($view,512,0,$g[0],$g[1]);[MathomirUiProbe]::Mouse($view,513,1,$g[0],$g[1]);
 for($i=0;$i -lt 8;$i++){[MathomirUiProbe]::Mouse($view,512,1,($g[0]+$dx),($g[1]+$dy))}
 if($release){[MathomirUiProbe]::Mouse($view,514,0,($g[0]+$dx),($g[1]+$dy))}
}
try {
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,0xE900)
 foreach($font in @(600,800,1200,2400)){foreach($power in @($false,$true)){foreach($zoom in @(60,100,200)){
  $script:fixture=Join-Path (Split-Path $exe) "large-resize-grip-$font-$power-$zoom.mom"
  $formula=if($power){'<elm tp="3" E1="" E2=""><ex fh="'+$font+'"><var t="e" f="00" /></ex><ex fh="'+[int]($font*.7)+'"><var t="2" f="00" /><var t="x" f="00" /></ex></elm>'}else{'<var t="e" f="00" />'}
  ('<?xml version="1.0"?><mathomir><o t="1" X="40" Y="180"><ex fh="'+$font+'">'+$formula+'</ex></o></mathomir>')|Set-Content $fixture -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 180
  [MathomirUiProbe]::Send($view,273,$(if($zoom -eq 60){32777}elseif($zoom -eq 200){33019}else{32775}))|Out-Null
  [MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
  [MathomirUiProbe]::Mouse($view,512,0,[int](45*$zoom/100),[int](175*$zoom/100));$before=SaveDoc;$original=$before.mathomir.FirstChild.OuterXml
  $g=Grip;Drag $g 70 40;$d=SaveDoc;$grown=Font $d
  if($grown -le $font){throw "Grip stopped growing at $font% ($power/$zoom), result $grown%."}
  if($power){$kids=$d.SelectNodes('/mathomir/*[1]/*[self::ex or self::expr]/elm[@tp="3"]/*[self::ex or self::expr] | /mathomir/*[1]/*[self::ex or self::expr]/pow/*[self::ex or self::expr]');if($kids.Count -ne 2){throw 'Power lost its editable children'};$base=if($kids[0].HasAttribute('fh')){[int]$kids[0].fh}else{[int]$kids[0].fnt_h};$exponent=if($kids[1].HasAttribute('fh')){[int]$kids[1].fh}else{[int]$kids[1].fnt_h};if([Math]::Abs($base-$grown) -gt 1 -or [Math]::Abs($exponent-.7*$grown) -gt 2){throw 'Large resize distorted base/exponent proportions'}}
  $g=Grip;Drag $g 45 25;$d=SaveDoc;$again=Font $d;if($again -le $grown){throw 'Could not re-grab and enlarge the large equation a second time'}
  $g=Grip;Drag $g -65 -35;$d=SaveDoc;if((Font $d) -ge $again){throw 'Could not shrink the enlarged equation'}
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$d=SaveDoc;if((Font $d) -ne $again){throw 'Undo did not restore the large font'}
  # Undo replaces document objects and clears their old hover handles. Reacquire
  # the real visible glyph before testing the next drag, rather than a blank
  # corner inside the oversized expression's bounding rectangle.
  HoverObject
  $g=Grip;Drag $g 80 45 $false;[MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null;$d=SaveDoc;if((Font $d) -ne $again){throw 'Escape did not cancel the large resize'}
  Write-Output "Large grip passed: $font% -> $grown% -> $again%, power=$power, zoom=$zoom; repeated events, re-grab, shrink, Undo, Escape."
 }}}
 # A drawing extends beyond both canvas edges; its grip remains inside the canvas.
 $script:fixture=Join-Path (Split-Path $exe) 'large-resize-grip-offscreen-drawing.mom'
 '<?xml version="1.0"?><mathomir><o t="2" X="40" Y="40"><dw d="32|0,0;28800,0;28800,19200;0,19200;0,0" /></o></mathomir>'|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200;[MathomirUiProbe]::Send($view,273,32775)|Out-Null;[MathomirUiProbe]::Mouse($view,512,0,100,40)
 $d=SaveDoc;$original=$d.mathomir.FirstChild.OuterXml;$g=Grip;$r=[MathomirUiProbe]::ClientRect($view);if($g[0] -gt $r.Right-8 -or $g[1] -gt $r.Bottom-8){throw 'Oversized drawing grip is outside the canvas'}
 Drag $g 80 60;$d=SaveDoc;if($d.mathomir.FirstChild.OuterXml -eq $original){throw 'Off-screen drawing did not resize'}
 $g=Grip;Drag $g -100 -80;$d=SaveDoc;[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$d=SaveDoc;if($d.mathomir.FirstChild.OuterXml -ne $original){throw 'Oversized drawing Undo failed'}
 Write-Output 'Off-screen corner passed: visible edge grip, enlargement, second drag, shrink, two Undos.'
}finally{
 if($main -ne [IntPtr]::Zero -and !$app.HasExited){Add-Type -AssemblyName System.Drawing;$r=[MathomirUiProbe]::WindowRect($main);$im=New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[System.Drawing.Graphics]::FromImage($im);$g.CopyFromScreen($r.Left,$r.Top,0,0,$im.Size);$im.Save((Join-Path (Split-Path $exe) 'large-resize-grip-ui.png'));$g.Dispose();$im.Dispose()}
 $app.Refresh();if(!$app.HasExited){$app.Kill();$app.WaitForExit()}
}
