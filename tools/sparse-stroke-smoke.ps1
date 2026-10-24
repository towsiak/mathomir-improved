$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $fixture -Raw)}
function Points($doc){$prev=$null;foreach($p in (ShaderPoints $doc.mathomir.FirstChild)){if(!$prev -or [Math]::Abs($p.x-$prev.x)+[Math]::Abs($p.y-$prev.y) -gt .00001){$p;$prev=$p}}}
function MaxTurn($points){[double]$max=0;for($i=1;$i -lt $points.Count-1;$i++){$ax=$points[$i].x-$points[$i-1].x;$ay=$points[$i].y-$points[$i-1].y;$bx=$points[$i+1].x-$points[$i].x;$by=$points[$i+1].y-$points[$i].y;$den=[Math]::Sqrt(($ax*$ax+$ay*$ay)*($bx*$bx+$by*$by));if($den -gt .00001){$cos=[Math]::Max(-1.0,[Math]::Min(1.0,($ax*$bx+$ay*$by)/$den));$max=[Math]::Max($max,[Math]::Acos($cos))}};return $max}
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,0xE900)
 # Geometry fixtures need their ink and controls inside the visible canvas.
 [MathomirUiProbe]::EnsureCanvas($main,$view,560,500);Start-Sleep -Milliseconds 150
 $fixture=Join-Path (Split-Path $exe) 'sparse-rounded-freehand.mom'
 # Follow the broad shape and sparse bends of the reported screenshot.
 $xy=@(@(92,478),@(334,401),@(362,373),@(380,329),@(373,295),@(346,271),@(314,261),@(262,267),@(177,284),@(103,291),@(67,263),@(81,203),@(175,156),@(262,148),@(348,172),@(398,198),@(499,227),@(514,224),@(550,199),@(579,143),@(578,103),@(573,74))
 $pairs=@($xy|ForEach-Object {([int](($_[0]-67)*.7*32)).ToString()+','+([int](($_[1]-74)*.7*32)).ToString()})
 ('<?xml version="1.0"?><mathomir><o t="2" X="60" Y="60"><dw free="1" d="32|'+($pairs -join ';')+'" /></o></mathomir>')|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250;[MathomirUiProbe]::Send($view,273,32775)|Out-Null
 $raw=SaveDoc;$original=$raw.mathomir.FirstChild.OuterXml;$rp=@(Points $raw);$rawTurn=MaxTurn $rp
 [MathomirUiProbe]::Send($main,273,33092)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null;[MathomirUiProbe]::Send($main,273,33094)|Out-Null
 $smooth=SaveDoc;$sp=@(Points $smooth);$turn=MaxTurn $sp
 if($sp.Count -le $rp.Count -or $turn -gt .3 -or $turn -ge $rawTurn*.3){Write-Output $smooth.OuterXml;throw "Sparse bends were not rounded: $($turn*180/[Math]::PI) degrees, raw $($rawTurn*180/[Math]::PI)."}
 foreach($end in @(0,-1)){if([Math]::Abs($sp[$end].x-$rp[$end].x) -gt .04 -or [Math]::Abs($sp[$end].y-$rp[$end].y) -gt .04){throw 'Sparse smoothing moved the endpoint'}}
 $saved=$smooth.mathomir.FirstChild.OuterXml
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$undo=SaveDoc;if($undo.mathomir.FirstChild.OuterXml -ne $original){throw 'Sparse smoothing Undo failed'}
 [MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null;[MathomirUiProbe]::Send($main,273,33094)|Out-Null;$smooth=SaveDoc
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250;$reopen=SaveDoc;if($reopen.mathomir.FirstChild.OuterXml -ne $saved){throw 'Smooth sparse curve changed on reopening'}
 [MathomirUiProbe]::Mouse($view,512,0,500,400)
 Write-Output "Sparse native curve passed: turns $($rawTurn*180/[Math]::PI) -> $($turn*180/[Math]::PI) degrees, fixed endpoints, Undo, saved/reopened smooth geometry."
}finally{
 if($main -ne [IntPtr]::Zero -and !$app.HasExited){Add-Type -AssemblyName System.Drawing;$r=[MathomirUiProbe]::WindowRect($main);$im=New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[System.Drawing.Graphics]::FromImage($im);$g.CopyFromScreen($r.Left,$r.Top,0,0,$im.Size);$im.Save((Join-Path (Split-Path $exe) 'sparse-stroke-ui.png'));$g.Dispose();$im.Dispose()}
 $app.Refresh();if(!$app.HasExited){$app.Kill();$app.WaitForExit()}
}
