$ErrorActionPreference='Stop'
$base=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $base.Substring(0,$base.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public sealed class PlacementSnapshot {
 public int Width,Height;public int[] Pixels;
 public void Dispose(){}
}
public static class PlacementProbe {
 [DllImport("user32.dll",CharSet=CharSet.Ansi)] static extern IntPtr GetPropA(IntPtr h,string key);
 [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr d,int x,int y,int w,int h,IntPtr s,int sx,int sy,uint rop);
 [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr d);
 [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr d,int w,int h);
 [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr d,IntPtr o);
 [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr d);
 [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr d);
 [StructLayout(LayoutKind.Sequential)] struct Info {public uint Size;public int Width,Height;public ushort Planes,BitCount;public uint Compression,SizeImage;public int XPels,YPels;public uint Used,Important;}
 [DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr d,IntPtr bmp,uint start,uint lines,int[] data,ref Info info,uint use);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int command);
 public static int Stat(IntPtr h,string key){return GetPropA(h,"MathomirPlacement_"+key).ToInt32()-1;}
 public static PlacementSnapshot Capture(IntPtr h,int w,int height){
  IntPtr screen=GetDC(h),buffer=CreateCompatibleDC(screen),bitmap=CreateCompatibleBitmap(screen,w,height),old=SelectObject(buffer,bitmap);
  try{if(!BitBlt(buffer,0,0,w,height,screen,0,0,0x00CC0020))throw new Exception("Canvas capture failed");SelectObject(buffer,old);old=IntPtr.Zero;
   var pixels=new int[w*height];var info=new Info{Size=40,Width=w,Height=-height,Planes=1,BitCount=32};
   if(GetDIBits(screen,bitmap,0,(uint)height,pixels,ref info,0)!=height)throw new Exception("Canvas pixels unavailable");
   return new PlacementSnapshot{Width=w,Height=height,Pixels=pixels};
  }finally{if(old!=IntPtr.Zero)SelectObject(buffer,old);DeleteObject(bitmap);DeleteDC(buffer);ReleaseDC(h,screen);}
 }
 static int Channel(int color,int shift){return (color>>shift)&255;}
 static bool Ink(int color,int threshold){return Math.Min(Channel(color,0),Math.Min(Channel(color,8),Channel(color,16)))<threshold;}
 public static int[] FirstInk(PlacementSnapshot image){for(int y=24;y<Math.Min(520,image.Height);y++)for(int x=40;x<Math.Min(600,image.Width);x++){int c=image.Pixels[y*image.Width+x];if(Channel(c,0)<90&&Channel(c,8)<90&&Channel(c,16)<90)return new[]{x,y};}throw new Exception("Source object has no visible ink");}
 public static int[] Compare(PlacementSnapshot a,PlacementSnapshot b,int left,int top,int right,int bottom){int ink=0,wrong=0;for(int y=Math.Max(0,top);y<Math.Min(a.Height,bottom);y++)for(int x=Math.Max(0,left);x<Math.Min(a.Width,right);x++){int p=a.Pixels[y*a.Width+x],q=b.Pixels[y*b.Width+x];if(!Ink(p,180)&&!Ink(q,180))continue;ink++;if(Math.Abs(Channel(p,0)-Channel(q,0))>18||Math.Abs(Channel(p,8)-Channel(q,8))>18||Math.Abs(Channel(p,16)-Channel(q,16))>18)wrong++;}return new[]{ink,wrong};}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path;$folder=Split-Path $exe
$env:MATHOMIR_PLACEMENT_DIAGNOSTICS='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $script:fixture -Raw)}
function Click($x,$y){[MathomirUiProbe]::Mouse($view,512,0,$x,$y);[MathomirUiProbe]::Mouse($view,513,1,$x,$y);[MathomirUiProbe]::Mouse($view,514,0,$x,$y)}
function Capture {return [PlacementProbe]::Capture($view,$width,$height)}
function SaveShot($snapshot,$path){
 $bitmap=New-Object System.Drawing.Bitmap $snapshot.Width,$snapshot.Height
 $rectangle=New-Object System.Drawing.Rectangle 0,0,$snapshot.Width,$snapshot.Height
 $data=$bitmap.LockBits($rectangle,[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
 try{[Runtime.InteropServices.Marshal]::Copy($snapshot.Pixels,0,$data.Scan0,$snapshot.Pixels.Length)}finally{$bitmap.UnlockBits($data)}
 try{$bitmap.Save($path)}finally{$bitmap.Dispose()}
}

function Grid($style,$snap){
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33099,[IntPtr]::Zero)|Out-Null
 $dialog=[IntPtr]::Zero
 for($n=0;$n -lt 60;$n++){Start-Sleep -Milliseconds 50;$dialog=[MathomirUiProbe]::Window($app.Id,'Grid styles and snapping');if($dialog -ne [IntPtr]::Zero){break}}
 Check ($dialog -ne [IntPtr]::Zero) 'Grid options did not open'
 [MathomirUiProbe]::Send([MathomirUiProbe]::Child($dialog,1360),334,$style)|Out-Null
 [MathomirUiProbe]::Send($dialog,273,((1-shl 16)-bor 1360))|Out-Null
 foreach($id in @(1362,1363)){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($dialog,$id),241,$snap)|Out-Null;[MathomirUiProbe]::Send($dialog,273,$id)|Out-Null}
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($dialog,1361),'16')
 [MathomirUiProbe]::Send($dialog,273,((5-shl 16)-bor 1361))|Out-Null
 [MathomirUiProbe]::Send($dialog,273,1)|Out-Null
}
function Grab($kind){
 [MathomirUiProbe]::Mouse($view,512,0,25,20)
 [MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null
 Check ([MathomirUiProbe]::Send($view,(0x8000+156),$kind) -eq 1) 'Native clipboard preparation failed'
}
function Scene($case,$zoom){
 $script:fixture=Join-Path $folder ('placement-preview-'+$case.name+'-'+$zoom+'.mom')
 ('<?xml version="1.0"?><mathomir>'+$case.objects+'</mathomir>')|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 220
 [MathomirUiProbe]::Send($view,273,$(if($zoom -eq 60){32777}elseif($zoom -eq 200){33019}else{32775}))|Out-Null
 [MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
 [MathomirUiProbe]::Mouse($view,512,0,25,20);Start-Sleep -Milliseconds 80
}
try {
 for($i=0;$i -lt 60;$i++){Start-Sleep -Milliseconds 100;$app.Refresh();if($app.MainWindowHandle -ne [IntPtr]::Zero){break}}
 $main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'No application window'
 [PlacementProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 $client=[MathomirUiProbe]::ClientRect($view);$width=$client.Right;$height=$client.Bottom
 $fraction='<fra E1="" E2=""><ex><var t="1" f="00" /></ex><ex><var t="2" f="00" /></ex></fra>'
 $power='<elm tp="3" E1="" E2=""><ex><var t="x" f="00" /></ex><ex>'+ $fraction +'</ex></elm>'
 $shape='<o t="2" X="80" Y="80"><dw d="32|0,0;3200,0;:,1920;0,:;:,0" /></o>'
 $ranges=@('-5','5','-5','5')|ForEach-Object{'<subexp d="0,0;2000,704"><ex><var t="'+$_+'" f="00" /></ex></subexp>'}
 $graph='<o t="2" X="80" Y="80"><dw spec="51" d="32|0,0;6400,0;:,5120;0,:;:,0" />'+($ranges -join '')+'<subexp d="0,0;4000,1000"><ex><var t="x" f="00" /></ex></subexp></o>'
 $cases=@(
  @{name='fraction-power';objects='<o t="1" X="80" Y="120"><ex fh="100">'+$power+'</ex></o>';kind=1},
  @{name='large-math';objects='<o t="1" X="80" Y="160"><ex fh="500">'+$power+'</ex></o>';kind=1},
  @{name='oversized';objects='<o t="1" X="80" Y="240"><ex fh="1200" stxt="1"><var t="PreviewClippingTest" f="00" /></ex></o>';kind=1},
  @{name='rotated';objects='<o t="1" X="80" Y="150"><ex fh="300" rot_mdeg="17500"><var t="rotation" f="00" /></ex></o>';kind=1},
  @{name='text';objects='<o t="1" X="80" Y="120"><ex fh="300" stxt="1"><var t="Preview" f="00" /></ex></o>';kind=1},
  @{name='shape';objects=$shape;kind=2},
  @{name='graph';objects=$graph;kind=2},
  @{name='mixed-group';objects=$shape+'<o t="1" X="85" Y="160"><ex fh="180">'+$power+'</ex></o>';kind=2}
 )
 $failures=@()
 $originalCases=@($cases)
 foreach($style in @(0,3,4,5)){foreach($source in @($originalCases[0],$originalCases[5])){$cases+=@{name=$source.name+'-grid-'+$style;objects=$source.objects;kind=$source.kind;style=$style;zooms=@(100)}}}
 Grid 0 0
 foreach($case in $cases){foreach($zoom in $(if($case.zooms){$case.zooms}else{@(60,100,200)})){
  try{
  if($case.ContainsKey('style')){Grid $case.style 1}else{Grid 0 0}
  Scene $case $zoom;$baseline=SaveDoc;$originalCount=$baseline.SelectNodes('/mathomir/*').Count
  Grab $case.kind
  $x=570;$y=350
  [MathomirUiProbe]::Mouse($view,512,0,$x,$y);Start-Sleep -Milliseconds 100
  Check ([PlacementProbe]::Stat($view,'Active') -eq 1) ('No live preview after grabbing '+$case.name+' at '+$zoom)
  Check ([PlacementProbe]::Stat($view,'Kind') -eq $case.kind) ('Unexpected preview mode for '+$case.name)
  Check ([PlacementProbe]::Stat($view,'Zoom') -eq $zoom) 'Preview silently changed zoom'
  $left=[PlacementProbe]::Stat($view,'Left');$top=[PlacementProbe]::Stat($view,'Top');$right=[PlacementProbe]::Stat($view,'Right');$bottom=[PlacementProbe]::Stat($view,'Bottom')
  $docX=[PlacementProbe]::Stat($view,'X');$docY=[PlacementProbe]::Stat($view,'Y')
  Check ((SaveDoc).OuterXml -eq $baseline.OuterXml) ('Hover changed the document: '+$case.name)
  $before=Capture
  if($case.name -eq 'large-math' -and $zoom -eq 200){SaveShot $before (Join-Path $folder 'placement-preview-before.png')}
  Click $x $y
  [MathomirUiProbe]::Mouse($view,512,0,25,20);Start-Sleep -Milliseconds 100
  $placed=SaveDoc;$after=Capture
  try{
   Check ($placed.SelectNodes('/mathomir/*').Count -eq 2*$originalCount) ('Placement changed object count: '+$case.name+' '+$placed.OuterXml)
   if($case.kind -eq 1){$last=$placed.mathomir.LastChild;Check ([int]$last.X -eq $docX -and [int]$last.Y -eq $docY) ('Preview and committed anchors differ: '+$placed.OuterXml)}
   $comparison=[PlacementProbe]::Compare($before,$after,$left,$top,$right,$bottom)
   Check ($comparison[0] -gt 15) ('Preview has no useful ink: '+$case.name)
   Check ($comparison[1] -le [Math]::Max(3,0.05*$comparison[0])) ('Preview differs from placed pixels: '+$case.name+' zoom='+$zoom+' ink='+$comparison[0]+' mismatch='+$comparison[1])
   if($case.name -eq 'large-math' -and $zoom -eq 200){SaveShot $after (Join-Path $folder 'placement-preview-after.png')}
  }finally{$before.Dispose();$after.Dispose()}
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null
  Check ((SaveDoc).OuterXml -eq $baseline.OuterXml) ('Undo did not restore placement: '+$case.name)
  Grab $case.kind;[MathomirUiProbe]::Mouse($view,512,0,$x,$y)
  [MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null
  [MathomirUiProbe]::Mouse($view,512,0,25,20)
  Check ([PlacementProbe]::Stat($view,'Active') -ne 1) 'Escape left a live preview'
  Check ((SaveDoc).OuterXml -eq $baseline.OuterXml) 'Cancel inserted or changed an object'
  Write-Output ('Placement preview passed: '+$case.name+' at '+$zoom+'%, native pixel match, unchanged hover, Undo and Escape.')
  }catch{
   $failure=$case.name+' at '+$zoom+': '+$_.Exception.Message;$failures+=$failure;Write-Output ('PREVIEW FAILURE: '+$failure)
   if($app.HasExited){throw}
   try{$shot=Capture;SaveShot $shot (Join-Path $folder ('placement-preview-failure-'+$case.name+'-'+$zoom+'.png'));$shot.Dispose();[MathomirUiProbe]::Send($view,256,27)|Out-Null;$null=SaveDoc}catch{throw}
  }
 }}
 Grid 0 0;Scene $originalCases[0] 100;$baseline=SaveDoc
 $sourceImage=Capture;try{$ink=[PlacementProbe]::FirstInk($sourceImage)}finally{$sourceImage.Dispose()}
 Grab 1;[MathomirUiProbe]::Mouse($view,512,0,$ink[0],$ink[1]);Start-Sleep -Milliseconds 100
 Check ([PlacementProbe]::Stat($view,'Kind') -eq 3) 'Existing math did not get a labelled compact insertion preview'
 Check ((SaveDoc).OuterXml -eq $baseline.OuterXml) 'Insertion preview changed native math'
 [MathomirUiProbe]::Send($view,256,27)|Out-Null
 Write-Output 'Compact existing-math insertion preview passed without changing the destination.'
 if($failures.Count){throw ('Placement preview failures: '+($failures -join '; '))}
}catch{
 if(Test-Path $fixture){Get-Content $fixture|Write-Output}
 try{$image=Capture;SaveShot $image (Join-Path $folder 'placement-preview-failure.png');$image.Dispose()}catch{}
 Get-ChildItem $folder -Filter 'asan*' -File|ForEach-Object{Get-Content $_.FullName|Write-Output}
 throw
}finally{if($app -and !$app.HasExited){$app.Kill();$app.WaitForExit()};Remove-Item Env:MATHOMIR_PLACEMENT_DIAGNOSTICS -ErrorAction SilentlyContinue}
