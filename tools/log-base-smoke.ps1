$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LogUI { [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h); }
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$appProcess=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function OpenBuilder {
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33101,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 30;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($appProcess.Id,'Logarithm builder');if($d -ne [IntPtr]::Zero){return $d}}
 throw 'Logarithm builder did not open'
}
function Place($d,$id,$x,$y){[MathomirUiProbe]::PostMessage($d,273,[IntPtr]$id,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 500;[MathomirUiProbe]::Mouse($view,512,0,$x,$y);[MathomirUiProbe]::Mouse($view,513,1,$x,$y);[MathomirUiProbe]::Mouse($view,514,0,$x,$y);[MathomirUiProbe]::Send($view,258,27)|Out-Null;Start-Sleep -Milliseconds 500}
try {
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 200;$appProcess.Refresh();if($appProcess.MainWindowHandle -ne 0){break}}
 $main=$appProcess.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,59648)
 $file=Join-Path (Split-Path $exe) 'log-base-smoke.mom';'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $file -Encoding ascii;[MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400
 # Actual new button at the end of the existing function palette.
 $toolbox=[MathomirUiProbe]::CaptionChild($main,'Toolbox');$r=[MathomirUiProbe]::WindowRect($toolbox);$size=$r.Right-$r.Left;$client=[MathomirUiProbe]::ClientRect($main)
 $height=[int][Math]::Floor(($client.Bottom-[Math]::Floor($size/2)-$size-7)/8);$height=[Math]::Max([Math]::Floor($size/3),[Math]::Min([Math]::Floor(2*$size/3),$height));if($height -lt $size/2){$height+=[Math]::Floor([Math]::Floor($size/3)/8)};$height=$height -band 0xFFFE
 $x=[int]($size/2)-3;$y=[int]($size/2)+5*$height-3;[MathomirUiProbe]::Mouse($toolbox,512,0,$x,$y);[MathomirUiProbe]::Mouse($toolbox,513,1,$x,$y);[MathomirUiProbe]::Mouse($toolbox,514,0,$x,$y);Start-Sleep -Milliseconds 150
 $palette=[MathomirUiProbe]::Window($appProcess.Id,'Subtoolbox');Check ($palette -ne [IntPtr]::Zero) 'Function palette missing'
 $x=[int](14*$size/2+$size/4);$y=[int]([Math]::Floor(2*$size/3)/2);[MathomirUiProbe]::Mouse($palette,512,0,$x,$y);[MathomirUiProbe]::PostMessage($palette,513,[IntPtr]1,[IntPtr](($y -shl 16) -bor $x))|Out-Null;[MathomirUiProbe]::PostMessage($palette,514,[IntPtr]0,[IntPtr](($y -shl 16) -bor $x))|Out-Null
 Start-Sleep -Milliseconds 500;$d=[MathomirUiProbe]::Window($appProcess.Id,'Logarithm builder');Check ($d -ne [IntPtr]::Zero) 'Actual logarithm palette button failed'
 [MathomirUiProbe]::Send($d,273,1389)|Out-Null;$report=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1387));Check ($report.Contains('≈ 4')) ('Wrong radical log value: '+$report)
 foreach($bad in @('1','0','-2','sqrt(-1)')){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1382),$bad);Check (![LogUI]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) ('Bad base accepted: '+$bad)}
 [MathomirUiProbe]::Send($d,273,1389)|Out-Null;Place $d 1 150 130
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw
 $log=$doc.SelectSingleNode('//elm[@tp="6" and @tx="log"]');Check ($log -and $log.SelectSingleNode('./expr[2]/elm[@tp="8"]')) 'Radical base was not saved as native log subscript'
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw;Check ($doc.SelectSingleNode('//elm[@tp="6" and @tx="log"]/expr[2]/elm[@tp="8"]')) 'Radical log base changed on reload'
 $d=OpenBuilder;[MathomirUiProbe]::Send($d,273,1389)|Out-Null;Place $d 1388 100 260;Start-Sleep -Seconds 2
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw;Check ($doc.SelectSingleNode('//obj[@type="2"]//elm[@tp="6" and @tx="log"]/expr[2]/elm[@tp="8"]')) 'Graph lost native logarithm or radical base'
 $black=[MathomirUiProbe]::CountColor($view,155,288,675,540,0);Check ($black -gt 100) 'Logarithm graph did not render'
 # Literal entry, including nested parentheses and comma.
 $file=Join-Path (Split-Path $exe) 'typed-log-base-smoke.mom';'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $file -Encoding ascii;[MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400
 [MathomirUiProbe]::Mouse($view,512,0,250,180);[MathomirUiProbe]::Mouse($view,513,1,250,180);[MathomirUiProbe]::Mouse($view,514,0,250,180)
 foreach($c in 'log(sqrt(3),9)'.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$c)|Out-Null}
 [MathomirUiProbe]::ExecuteKey($view,$false);[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw;Check ($doc.SelectSingleNode('//elm[@tp="2" and @stp="\BB"]') -and $doc.SelectSingleNode('//elm[@tp="1" and @tx="4"]')) ('Typed radical-base log did not evaluate inline: '+$doc.OuterXml)
 Write-Output 'Logarithm UI passed: actual function-palette button, radical base preview/value, invalid bases, native placement/save/reload, graph creation and literally typed inline evaluation.'
}finally{if(!$appProcess.HasExited){$appProcess.Kill();$appProcess.WaitForExit()}}
