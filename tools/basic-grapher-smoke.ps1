$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BasicGraphProbe {
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int mode);
 [DllImport("user32.dll",EntryPoint="GetWindowLongW")] static extern int GetWindowLong(IntPtr h,int index);
 public static bool ClipsChildren(IntPtr h){return (GetWindowLong(h,-16)&0x02000000)!=0;}
 [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc,int x,int y);
 public static int[] Axes(IntPtr h){IntPtr dc=GetDC(h);try{for(int y=101;y<180;y++)for(int x=160;x<555;x++)if(GetPixel(dc,x,y)==0x00C8AA82)return new[]{x,y};throw new Exception("Axes / units button absent");}finally{ReleaseDC(h,dc);}}
 public static int[] Dot(IntPtr h,uint color){IntPtr dc=GetDC(h);try{for(int y=103;y<250;y++)for(int x=570;x<599;x++)if(GetPixel(dc,x,y)==color)return new[]{x,y};throw new Exception("Native function button absent");}finally{ReleaseDC(h,dc);}}
}
'@
function Check($ok,$why){if(!$ok){throw $why}}
function Click($x,$y){[MathomirUiProbe]::Mouse($view,512,0,$x,$y);[MathomirUiProbe]::Mouse($view,513,1,$x,$y);[MathomirUiProbe]::Mouse($view,514,0,$x,$y)}
function TypeMath($text){foreach($c in $text.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$c)|Out-Null}}
function EscapeView{[MathomirUiProbe]::Send($view,258,27)|Out-Null;[MathomirUiProbe]::Mouse($view,512,0,850,50);Start-Sleep -Milliseconds 800}
function SaveDoc{[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $file -Raw)}
function Capture($name){$r=[MathomirUiProbe]::WindowRect($main);$b=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[Drawing.Graphics]::FromImage($b);try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size);$b.Save((Join-Path $folder $name))}finally{$g.Dispose();$b.Dispose()}}
function OpenAxes{
 # Match the native blue outline, instead of assuming a palette size.
 [MathomirUiProbe]::Mouse($view,512,0,400,220);Start-Sleep -Milliseconds 180
 $p=[BasicGraphProbe]::Axes($view);Click ($p[0]+12) ($p[1]+8)
 for($i=0;$i -lt 20;$i++){Start-Sleep -Milliseconds 50;$h=[MathomirUiProbe]::Child($view,1710);if($h -ne [IntPtr]::Zero -and [MathomirUiProbe]::IsWindowVisible($h)){return $h}}
 throw 'Inline axis editor did not open'
}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe;$file=Join-Path $folder 'basic-grapher-input.mom'
$graph='<?xml version="1.0"?><mathomir><o t="2" X="100" Y="100"><dw spec="51" d="32|32,32;16000,32;:,11520;32,:;:,32"/>'
foreach($n in @('-10','10','-10','10')){$graph+='<subexp d="0,0;0,0"><ex fh="100"><var t="'+$n+'" f="00"/></ex></subexp>'}
$graph+='<subexp d="0,0;0,0"><ex fh="100"/></subexp></o></mathomir>';$graph|Set-Content $file -Encoding ascii
$env:MATHOMIR_GRAPH_DIAGNOSTICS='1';$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start';[BasicGraphProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 $single=Join-Path $folder 'basic-grapher-single.mom';$graph|Set-Content $single -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$single);Start-Sleep -Milliseconds 600;[MathomirUiProbe]::Send($main,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,0)|Out-Null
 [MathomirUiProbe]::Mouse($view,512,0,400,220);Start-Sleep -Milliseconds 200;$one=[BasicGraphProbe]::Dot($view,0x0000CC00);Click $one[0] $one[1];TypeMath '(1,2)';EscapeView
 Check (@(Get-Content (Join-Path $folder 'graph-diagnostics.txt')|Where-Object{$_ -match '^point list slot,count,valid,bound: 1 1 1 '}).Count -gt 0) 'A single typed pair did not plot';[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 600;[MathomirUiProbe]::Send($main,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,0)|Out-Null
 [MathomirUiProbe]::Mouse($view,512,0,400,220);Start-Sleep -Milliseconds 200
 $dot=[BasicGraphProbe]::Dot($view,0x0000CC00);Click $dot[0] $dot[1];TypeMath '(1,2),(3,4),(5,6)';EscapeView;$s=SaveDoc
 $slots=$s.SelectNodes('/mathomir/*[*[self::dw or self::draw][@spec="51"]]/subexp[position()>4]');Check ($slots.Count -eq 8) 'Basic graph did not retain all native input slots'
 $text=($slots[1].SelectNodes('.//var | .//elm[@tp="1"]')|ForEach-Object{if($_.HasAttribute('t')){$_.t}else{$_.tx}})-join '';Check ($text -eq '123456') ('Point entry was changed: '+$slots[1].OuterXml)
 $log=Get-Content (Join-Path $folder 'graph-diagnostics.txt');Check (@($log|Where-Object{$_ -match '^point list slot,count,valid,bound: 1 3 1 '}).Count -gt 0) 'Literally typed list did not parse as three points'
 $viewport=@($log|Where-Object{$_ -match '^point viewport left,top,width,height:'})[-1] -split ': ',2;$left=[double]($viewport[1] -split ' ')[0]
 $pixels=@($log|Where-Object{$_ -match '^typed point pixel x,y,slot,radius: .* 1 4$'}|Select-Object -Last 3);Check ($pixels.Count -eq 3) 'Points were not rendered'
 foreach($line in $pixels){$v=($line -split ': ',2)[1] -split ' ';$x=101+[int]([double]$v[0])+$left;$y=101+[int]([double]$v[1]);Check ([MathomirUiProbe]::CountColor($view,($x-5),($y-5),11,11,0x0000CC00) -gt 30) 'Typed point has no visible dot'}
 Capture 'basic-grapher-point-list.png'
 # A regular curve uses another slot on the same graph.
 [MathomirUiProbe]::Mouse($view,512,0,400,220);Start-Sleep -Milliseconds 180;$red=[BasicGraphProbe]::Dot($view,0x000000CC);Click $red[0] $red[1];TypeMath 'x';EscapeView;$mixed=SaveDoc
 Check ($mixed.mathomir.ChildNodes.Count -eq 1) 'Mixing points and a curve duplicated the graph';Check ([MathomirUiProbe]::CountColor($view,175,180,370,250,0x000000CC) -gt 50) 'Regular curve disappeared beside points'
 $d=OpenAxes;Check ([BasicGraphProbe]::GetParent($d) -eq $view -and [MathomirUiProbe]::IsWindowEnabled($main)) 'Axis editor is external or modal';Check ([BasicGraphProbe]::ClipsChildren($view)) 'Canvas repaint can cover the inline axis controls'
 $dr=[MathomirUiProbe]::WindowRect($d);$vr=[MathomirUiProbe]::WindowRect($view);Check ($dr.Left -ge $vr.Left+100 -and $dr.Right -le $vr.Left+601 -and $dr.Top -ge $vr.Top+100 -and $dr.Bottom -le $vr.Top+461) 'Axis controls are outside their graph'
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1711),'t');[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1712),'s');[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1713),'v');[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1714),('m/s'+[char]0x00B2));Capture 'basic-grapher-inline-units.png';[MathomirUiProbe]::Send($d,273,1715)|Out-Null
 $withUnits=SaveDoc;$axis=$withUnits.SelectSingleNode('//graphaxes');Check ($axis.xn -eq '74' -and $axis.xu -eq '73' -and $axis.yn -eq '76' -and $axis.yu -eq '6D2F73C2B2') 'Inline units did not persist as Unicode'
 Check ($withUnits.SelectNodes('//datum').Count -eq 0 -and $withUnits.SelectNodes('//plotdata').Count -eq 0) 'Native point list was converted to external table data'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;Check ($null -eq (SaveDoc).SelectSingleNode('//graphaxes')) 'Inline axis edit did not Undo'
 $d=OpenAxes;[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1711),'');[MathomirUiProbe]::Send($d,273,1715)|Out-Null;Check ([MathomirUiProbe]::IsWindowVisible($d)) 'Empty axis name was accepted';[MathomirUiProbe]::Send($d,273,1716)|Out-Null;Check ($null -eq (SaveDoc).SelectSingleNode('//graphaxes')) 'Cancel changed axis names'
 # Reopen the exact saved point expressions and units, then switch documents while editing.
 $file=Join-Path $folder 'basic-grapher-reopened.mom';$withUnits.Save($file);[MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Seconds 1;$d=OpenAxes
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1714)) -eq ('m/s'+[char]0x00B2)) 'Units lost on reopen';Capture 'basic-grapher-reopened.png'
 $blank=Join-Path $folder 'basic-grapher-other-document.mom';'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $blank -Encoding ascii;[MathomirUiProbe]::OpenFile($main,$blank);Start-Sleep -Milliseconds 400;Check (![MathomirUiProbe]::IsWindowVisible($d)) 'Axis editor retained a stale document target'
 Write-Output 'Basic grapher passed: literally typed ordered pairs, three visible exact dots, mixed curve slot, in-graph Unicode units, save/reopen, Undo, cancel, invalid-name guard and document lifetime.'
}catch{if($main){Capture 'basic-grapher-failure.png'};throw}finally{if($app -and !$app.HasExited){Stop-Process -Id $app.Id -Force};Remove-Item Env:MATHOMIR_GRAPH_DIAGNOSTICS -ErrorAction SilentlyContinue}
