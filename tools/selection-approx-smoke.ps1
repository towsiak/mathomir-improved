$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$appProcess=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
$script:fixtureNumber=0;$script:file=$null
function Check($ok,$message){if(!$ok){throw $message}}
function LoadMath($body){
 if($script:file){[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null}
 $script:fixtureNumber++;$script:file=Join-Path (Split-Path $exe) ('selection-approx-'+$script:fixtureNumber+'-smoke.mom')
 ('<?xml version="1.0"?><mathomir><o t="1" X="100" Y="130"><ex fh="200">'+$body+'</ex></o></mathomir>')|Set-Content $file -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 500;[MathomirUiProbe]::Send($main,273,32775)|Out-Null
}
function Panel { [MathomirUiProbe]::CaptionChild($view,'Math selection') }
function WholePanel {
 [MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null
 [MathomirUiProbe]::Mouse($view,512,0,105,126);Start-Sleep -Milliseconds 150
 $p=Panel;Check ($p -ne [IntPtr]::Zero -and [MathomirUiProbe]::IsWindowVisible($p)) 'Highlighting did not show the approximation panel'
 return $p
}
function Places($p,$digits){$combo=[MathomirUiProbe]::Child($p,1391);[MathomirUiProbe]::Send($combo,334,($digits+1))|Out-Null;[MathomirUiProbe]::Send($p,273,((1 -shl 16) -bor 1391))|Out-Null;Start-Sleep -Milliseconds 100}
function ResultText($p){[MathomirUiProbe]::Text([MathomirUiProbe]::Child($p,1393))}
function Apply($p){$button=[MathomirUiProbe]::Child($p,1390);[MathomirUiProbe]::Mouse($button,512,0,30,12);[MathomirUiProbe]::Mouse($button,513,1,30,12);[MathomirUiProbe]::Mouse($button,514,0,30,12);Start-Sleep -Milliseconds 200;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $file -Raw)}
$power='<elm tp="3" E1="" E2=""><ex><var t="e" f="00" /></ex><ex><var t="p" f="60" /></ex></elm>'
try{
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 200;$appProcess.Refresh();if($appProcess.MainWindowHandle -ne 0){break}}
 $main=$appProcess.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,59648);Check ($view -ne [IntPtr]::Zero) ('No view: '+[MathomirUiProbe]::AllText($main));Write-Output ('Selection test frame: '+[MathomirUiProbe]::Text($main))
 LoadMath $power;$p=WholePanel;Places $p 2;Check ((ResultText $p) -eq '≈ 23.14') ('Wrong e-to-pi preview: '+(ResultText $p))
 Write-Output 'Whole-expression panel and live rounded preview passed.'
 # The dropdown remains open and the highlight survives the trip to the panel.
 $combo=[MathomirUiProbe]::Child($p,1391);[MathomirUiProbe]::Send($combo,335,1)|Out-Null;Start-Sleep -Milliseconds 300;Check ([MathomirUiProbe]::IsWindowVisible($p)) 'Panel hid while decimal choices were open';[MathomirUiProbe]::Send($combo,335,0)|Out-Null
 $button=[MathomirUiProbe]::Child($p,1390);[MathomirUiProbe]::Mouse($button,512,0,30,12);Start-Sleep -Milliseconds 150
 Add-Type -AssemblyName System.Drawing;$rect=[MathomirUiProbe]::WindowRect($view);$image=New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top);$graphics=[System.Drawing.Graphics]::FromImage($image);$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$image.Size);$image.Save((Join-Path (Split-Path $exe) 'selection-approx-ui.png'));$graphics.Dispose();$image.Dispose()
 $doc=Apply $p;Check ($doc.SelectSingleNode('//elm[@tp="3"]') -and $doc.SelectSingleNode('//elm[@tp="2" and @stp="\BB"]') -and $doc.SelectSingleNode('//elm[@tp="1" and @tx="23.14"]')) ('Approximate button lost original or result: '+$doc.OuterXml)
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;Check ((Get-Content $file -Raw) -notmatch '23\.14') 'Undo failed'
 foreach($digits in @(0,4,8)){$p=WholePanel;Places $p $digits;$doc=Apply $p;$want=if($digits -eq 0){'23'}elseif($digits -eq 4){'23.1407'}else{'23.14069263'};Check ($doc.SelectSingleNode('//elm[@tp="1" and @tx="'+$want+'"]')) ('Wrong decimal places: '+$digits);[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null}
 LoadMath '<var t="2" f="00" />';$p=WholePanel;Places $p 2;$doc=Apply $p;Check ($doc.SelectSingleNode('//elm[@tp="1" and @tx="2.00"]')) ('Requested trailing zeroes were lost: '+$doc.OuterXml)
 # Hover a selected power inside a sum; only the highlighted part is replaced.
 LoadMath ('<var t="2" f="00" /><opr s="+" />'+$power);$found=$false
 for($y=108;$y -le 130 -and !$found;$y+=3){for($x=129;$x -le 185;$x+=3){[MathomirUiProbe]::Mouse($view,512,0,$x,$y);$p=Panel;if($p -ne [IntPtr]::Zero -and [MathomirUiProbe]::IsWindowVisible($p)){Places $p 2;if((ResultText $p) -eq '≈ 23.14'){$found=$true;break}}}}
 Check $found 'Selected subexpression did not show its own approximation';$doc=Apply $p
 Check ($doc.SelectSingleNode('//elm[@tp="1" and @tx="2"]') -and $doc.SelectSingleNode('//elm[@tp="1" and @tx="23.14"]') -and !$doc.SelectSingleNode('//elm[@tp="2" and @stp="\BB"]') -and !$doc.SelectSingleNode('//elm[@tp="3"]')) ('Partial approximation changed surrounding math: '+$doc.OuterXml)
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;[xml]$doc=Get-Content $file -Raw;Check ($doc.SelectSingleNode('//elm[@tp="3"]')) 'Partial approximation Undo failed'
 LoadMath $power;$p=WholePanel;[MathomirUiProbe]::Send($p,273,1392)|Out-Null;Start-Sleep -Milliseconds 400;Check (![MathomirUiProbe]::IsWindowVisible($p)) 'Dismissed panel reopened'
 LoadMath '<fun t="ln" E1=""><ex><var t="-1" f="00" /></ex></fun>';[MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null;[MathomirUiProbe]::Mouse($view,512,0,105,126);$p=Panel;Check ($p -eq [IntPtr]::Zero -or ![MathomirUiProbe]::IsWindowVisible($p)) 'Undefined logarithm showed an approximation'
 # Per-result decimals must not change the normal approximation preference.
 LoadMath $power;[MathomirUiProbe]::ExecuteKey($view,$true);[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;Check ((Get-Content $file -Raw) -match '23\.1406926328') 'Panel changed global rounding preferences'
 Write-Output 'Selection approximation passed: automatic panel, live Unicode preview, actual Approximate button, decimal dropdown, 0/2/4/8 places, trailing zeroes, original retention, partial replacement, Undo, dismissal, undefined-domain rejection and unchanged global rounding.'
}catch{Write-Output ([MathomirUiProbe]::AllText($main));$trace=Join-Path (Split-Path $exe) 'selection-approx-diagnostics.txt';if(Test-Path $trace){Get-Content $trace|Select-Object -Last 30|Write-Output};throw}finally{if(!$appProcess.HasExited){$appProcess.Kill();$appProcess.WaitForExit()}}
