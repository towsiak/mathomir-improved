$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class IntegralUI {
 [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$env:MATHOMIR_GRAPH_DIAGNOSTICS='1'
$appProcess=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function Palette {
 $toolbox=[MathomirUiProbe]::CaptionChild($main,'Toolbox');$toolRect=[MathomirUiProbe]::WindowRect($toolbox);$toolSize=$toolRect.Right-$toolRect.Left
 $client=[MathomirUiProbe]::ClientRect($main)
 $height=[int][Math]::Floor(($client.Bottom-[Math]::Floor($toolSize/2)-$toolSize-7)/8)
 $height=[Math]::Max([Math]::Floor($toolSize/3),[Math]::Min([Math]::Floor(2*$toolSize/3),$height))
 if($height -lt $toolSize/2){$height+=[Math]::Floor([Math]::Floor($toolSize/3)/8)}
 $height=$height -band 0xFFFE
 $x=$toolSize-3;$y=[Math]::Floor($toolSize/2)+8*$height-3
 [MathomirUiProbe]::Mouse($toolbox,512,0,$x,$y);[MathomirUiProbe]::Mouse($toolbox,513,1,$x,$y);[MathomirUiProbe]::Mouse($toolbox,514,0,$x,$y)
 Start-Sleep -Milliseconds 150
 $palette=[MathomirUiProbe]::Window($appProcess.Id,'Subtoolbox');Check ($palette -ne [IntPtr]::Zero) 'Calculus palette did not open'
 return @{window=$palette;size=$toolSize}
}
function ClickPalette($row){$p=Palette;$x=[int]($p.size/4);$y=[int]($p.size/3+$row*2*$p.size/3)
 [MathomirUiProbe]::Mouse($p.window,512,0,$x,$y);[MathomirUiProbe]::PostMessage($p.window,513,[IntPtr]1,[IntPtr](($y -shl 16) -bor $x))|Out-Null;[MathomirUiProbe]::PostMessage($p.window,514,[IntPtr]0,[IntPtr](($y -shl 16) -bor $x))|Out-Null
}
function IntegralDialog {
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33100,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($appProcess.Id,'Integral area shader');if($d -ne [IntPtr]::Zero){return $d}}
 throw 'Integral dialog did not open'
}
try {
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 200;$appProcess.Refresh();if($appProcess.MainWindowHandle -ne 0){break}}
 $main=$appProcess.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,0xE900)
 Check ($view -ne [IntPtr]::Zero) 'No application view'
 $file=Join-Path (Split-Path $exe) 'integral-area-smoke.mom'
 '<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $file -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400;[MathomirUiProbe]::Send($main,273,32775)|Out-Null
 ClickPalette 0
 $d=[IntPtr]::Zero;for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($appProcess.Id,'Integral area shader');if($d -ne [IntPtr]::Zero){break}}
 Check ($d -ne [IntPtr]::Zero) 'Integral palette button did not open its dialog'
 Check ([IntegralUI]::IsWindowUnicode([MathomirUiProbe]::Child($d,1378))) 'Integral readout is not Unicode'
 $report=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1378));Check ($report.Contains('Signed integral') -and $report.Contains('≈ 2') -and $report.Contains('Total area')) "Incorrect sine readout: $report"
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1370),'1/(x-0.3)');[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1371),'-2');[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1372),'2');[MathomirUiProbe]::Send($d,273,1376)|Out-Null
 Check (![IntegralUI]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) 'Pole allowed integral placement'
 [MathomirUiProbe]::Send($d,273,1380)|Out-Null
 $report=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1378));Check ($report.Contains('Signed integral ≈ 0') -and $report.Contains('Total area ≈ 4')) "Signed/absolute readout: $report"
 [MathomirUiProbe]::PostMessage($d,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;if(![MathomirUiProbe]::IsWindowVisible($d)){break}}
 [MathomirUiProbe]::Mouse($view,512,0,100,100);[MathomirUiProbe]::Mouse($view,513,1,100,100);[MathomirUiProbe]::Mouse($view,514,0,100,100);[MathomirUiProbe]::Send($view,258,27)|Out-Null
 Start-Sleep -Seconds 2;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
 [xml]$doc=Get-Content $file -Raw;$stored=$doc.SelectSingleNode('//integral')
 Check ($stored -and $stored.a -eq '-2' -and $stored.b -eq '2' -and $stored.f -eq '78') 'Integral metadata missing or wrong'
 foreach($color in @(0x00FDEADB,0x00E5DEFC)){Check ([MathomirUiProbe]::CountColor($view,100,100,720,550,$color) -gt 100) "Missing positive/negative tint: $color"}
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Seconds 2
 foreach($color in @(0x00FDEADB,0x00E5DEFC)){Check ([MathomirUiProbe]::CountColor($view,100,100,720,550,$color) -gt 100) "Shading vanished on reload: $color"}
 # Select the placed graph and edit it instead of creating a duplicate.
 [MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null;$d=IntegralDialog
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1370)) -eq 'x') 'Selected integral formula not restored'
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1371),'2');[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1372),'-2');[MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1374),241,1)|Out-Null;[MathomirUiProbe]::Send($d,273,1376)|Out-Null
 [MathomirUiProbe]::PostMessage($d,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 700;[MathomirUiProbe]::Send($view,258,27)|Out-Null;Start-Sleep -Seconds 1
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw
 Check ($doc.SelectNodes('//integral').Count -eq 1 -and $doc.SelectSingleNode('//integral').hatch -eq '1') 'Editing duplicated graph or lost hatch option'
 Check ([MathomirUiProbe]::CountColor($view,100,100,720,550,0x00B97D50) -gt 20) 'Hatch strokes were not rendered'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw
 Check ($doc.SelectSingleNode('//integral').a -eq '-2' -and $doc.SelectSingleNode('//integral').hatch -eq '0') 'Undo did not restore original integral settings'
 Write-Output 'Integral native UI passed: actual palette, Unicode readouts, invalid pole, signed/absolute area, colored rendering, save/reload, edit, hatch and Undo.'
 # Native powers expand the stored formula beyond the old 160-character cap.
 $longFile=Join-Path (Split-Path $exe) 'long-integral-formula-smoke.mom';'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $longFile -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$longFile);Start-Sleep -Milliseconds 400;$d=IntegralDialog
 $longFormula=(2..30 | ForEach-Object {'x^'+$_}) -join '+'
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1370),$longFormula);[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1371),'0');[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1372),'1');[MathomirUiProbe]::Send($d,273,1376)|Out-Null
 Check ([IntegralUI]::IsWindowEnabled([MathomirUiProbe]::Child($d,1))) 'Long valid formula was rejected'
 [MathomirUiProbe]::PostMessage($d,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 600
 [MathomirUiProbe]::Mouse($view,512,0,100,100);[MathomirUiProbe]::Mouse($view,513,1,100,100);[MathomirUiProbe]::Mouse($view,514,0,100,100);[MathomirUiProbe]::Send($view,258,27)|Out-Null;Start-Sleep -Seconds 2
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $longFile -Raw;$longHex=$doc.SelectSingleNode('//integral').f
 Check ($longHex.Length -gt 320) 'Long-formula fixture did not exercise the expanded native storage'
 [MathomirUiProbe]::OpenFile($main,$longFile);Start-Sleep -Seconds 2;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $longFile -Raw
 Check ($doc.SelectSingleNode('//integral').f -eq $longHex) 'Long integral formula was truncated on reload'
 Write-Output 'Long native integral formula round trip passed without truncation.'
 # Literal typed ln(2), ordinary Execute and the actual evaluation palette.
 foreach($method in @('keyboard','palette')){
  $file=Join-Path (Split-Path $exe) ('inline-ln2-'+$method+'.mom');'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $file -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400
  [MathomirUiProbe]::Mouse($view,512,0,250,180);[MathomirUiProbe]::Mouse($view,513,1,250,180);[MathomirUiProbe]::Mouse($view,514,0,250,180)
  foreach($c in 'ln(2)'.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$c)|Out-Null}
  if($method -eq 'keyboard'){[MathomirUiProbe]::ExecuteKey($view,$false)}else{ClickPalette 1;Start-Sleep -Milliseconds 300}
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw;$root=$doc.SelectSingleNode('/mathomir/*[1]/*[self::ex or self::expr]')
  Check ($root.OuterXml -match '0\.69314718056') "ln(2) was not evaluated inline by $method : $($root.OuterXml)"
  $before=$root.OuterXml;[MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null;[MathomirUiProbe]::Send($main,273,33095)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw
  Check ($doc.SelectSingleNode('/mathomir/*[1]/*[self::ex or self::expr]').OuterXml -eq $before) 'Evaluation duplicated result'
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw
  Check ($doc.OuterXml -notmatch '0\.69314718056') 'Evaluation Undo failed'
 }
 Write-Output 'Inline function evaluation passed: literally typed ln(2), Ctrl+Enter and actual palette button, preserved original, replacement on repeated execution and Undo.'
}catch{
 $client=[MathomirUiProbe]::ClientRect($view)
 foreach($color in @(0x00FDEADB,0x00E5DEFC,0x00B97D50,0x00735FB4)){Write-Output ("Diagnostic full-view color "+$color+": "+[MathomirUiProbe]::CountColor($view,0,0,$client.Right,$client.Bottom,$color))}
 if(Test-Path $file){Write-Output (Get-Content $file -Raw)}
 $diagnostics=Join-Path (Split-Path $exe) 'graph-diagnostics.txt';if(Test-Path $diagnostics){Write-Output (Get-Content $diagnostics -Tail 25)}
 try{Add-Type -AssemblyName System.Drawing;$rect=[MathomirUiProbe]::WindowRect($view);$image=New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top);$graphics=[System.Drawing.Graphics]::FromImage($image);$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$image.Size);$image.Save((Join-Path (Split-Path $exe) 'integral-ui.png'));$graphics.Dispose();$image.Dispose()}catch{Write-Output $_}
 throw
}finally{Remove-Item Env:MATHOMIR_GRAPH_DIAGNOSTICS -ErrorAction SilentlyContinue;if(!$appProcess.HasExited){Stop-Process -Id $appProcess.Id -Force}}
