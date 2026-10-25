$ErrorActionPreference='Stop'
$base=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
$helpers=Get-Content (Join-Path $PSScriptRoot 'basic-grapher-smoke.ps1') -Raw
Invoke-Expression $base.Substring(0,$base.IndexOf('$exe ='))
$start=$helpers.IndexOf('Add-Type -AssemblyName');$end=$helpers.IndexOf('$exe=')
Invoke-Expression $helpers.Substring($start,$end-$start)
Add-Type @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public static class FeatureAuditProbe {
 [DllImport("user32.dll")] static extern uint GetGuiResources(IntPtr process,uint flags);
 [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr h,IntPtr update,IntPtr region,uint flags);
 public static uint Gdi(int pid){using(Process p=Process.GetProcessById(pid)){return GetGuiResources(p.Handle,0);}}
 public static void Paint(IntPtr h){RedrawWindow(h,IntPtr.Zero,IntPtr.Zero,0x181);}
}
'@
function Press($h,$id){[MathomirUiProbe]::Send($h,273,$id)|Out-Null;Start-Sleep -Milliseconds 80}
function Field($h,$id,$text){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($h,$id),$text)}
function OpenDock($command){[MathomirUiProbe]::Send($main,273,$command)|Out-Null;Start-Sleep -Milliseconds 180;return [MathomirUiProbe]::Child($view,33116)}
function AxesSaved($xn,$xu,$yn,$yu){$s=SaveDoc;$a=$s.SelectSingleNode('//graphaxes');Check ($a.xn -eq $xn -and $a.xu -eq $xu -and $a.yn -eq $yn -and $a.yu -eq $yu) ('Axis editors overwrote one another: '+$a.OuterXml);return $s}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe;$file=Join-Path $folder 'feature-audit-linked.mom'
$graph='<?xml version="1.0"?><mathomir><o t="2" X="100" Y="100"><dw spec="51" d="32|32,32;16000,32;:,11520;32,:;:,32"/><objectinfo oid="1"/>'
foreach($n in @('-10','10','-10','10')){$graph+='<subexp d="0,0;0,0"><ex fh="100"><var t="'+$n+'" f="00"/></ex></subexp>'}
$graph+='<subexp d="0,0;0,0"><ex fh="100"><var t="a" f="00"/><opr s="*"/><var t="x" f="00"/></ex></subexp></o>'
for($i=0;$i -lt 12;$i++){$graph+='<o t="1" X="'+(20+($i%6)*85)+'" Y="'+(540+[int][Math]::Floor($i/6)*100)+'"><ex fh="80" oid="'+($i+2)+'" tgraph="1" tstart="0" tstep="1" tcount="2" tslot="0"/></o>'}
$graph+='</mathomir>';$graph|Set-Content $file -Encoding ascii
$env:MATHOMIR_FEATURE_DIAGNOSTICS='1';$env:MATHOMIR_GRAPH_DIAGNOSTICS='1'
# Start with a fresh allocator. ID 2 is missing but referenced by a linked table;
# creating a new native graph must reserve that ID rather than reusing it.
$mainFixture=$file;$file=Join-Path $folder 'feature-audit-reserved-reference.mom'
'<?xml version="1.0"?><mathomir><o t="1" X="40" Y="60"><ex fh="100" oid="1" tgraph="2" tcount="2"><var t="KEEP" f="00"/></ex></o></mathomir>'|Set-Content $file -Encoding ascii
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;[BasicGraphProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400;[MathomirUiProbe]::Send($main,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,0)|Out-Null
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33106,[IntPtr]::Zero)|Out-Null;$dialog=[IntPtr]::Zero
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 50;$dialog=[MathomirUiProbe]::Window($app.Id,'Relations and parametric curves');if($dialog -ne [IntPtr]::Zero){break}}
 Check ($dialog -ne [IntPtr]::Zero) 'Could not create the reference-ID test graph';[MathomirUiProbe]::PostMessage($dialog,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 250;Click 150 150;EscapeView;$s=SaveDoc
 Check ($s.SelectNodes('//*[@oid="2"]').Count -eq 0) 'A new native object reused a still-referenced missing ID'
 Check ($s.mathomir.ChildNodes.Count -eq 2 -and $s.OuterXml.Contains('KEEP')) 'A missing graph reference silently attached to the new graph';Capture 'feature-audit-reserved-reference.png'
 Write-Output 'Native identity audit passed: a new graph does not reuse a missing target ID or alter the orphaned linked table.'
}catch{if($main){Capture 'feature-audit-identity-failure.png'};throw}finally{if($app -and !$app.HasExited){Stop-Process -Id $app.Id -Force;$app.WaitForExit()}}
$file=$mainFixture;$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;[BasicGraphProbe]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 600;[MathomirUiProbe]::Send($main,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,0)|Out-Null;Start-Sleep -Milliseconds 200
 $s=SaveDoc;Check ($s.SelectNodes('//ex[@tgraph] | //expr[@tgraph]').Count -eq 12) 'Linked table audit fixture was not loaded'
 $log=Get-Content (Join-Path $folder 'feature-audit-diagnostics.txt');$inside=$false;$walks=0;$hashes=0;$frames=0
 foreach($line in $log){if($line -like 'feature frame begin*'){$inside=$true;$walks=0;$hashes=0}elseif($line -like 'feature frame end*' -and $inside){Check ($walks -eq 1) "Feature synchronization rebuilt the document $walks times";Check ($hashes -le 1) "One graph was checksummed $hashes times for linked tables";$frames++;$inside=$false}elseif($inside){if($line -like 'document walk*'){$walks++};if($line -like 'linked graph checksum*'){$hashes++}}}
 Check ($frames -ge 1 -and @($log|Where-Object{$_ -like 'linked graph checksum 1'}).Count -gt 0) 'Shared synchronization path was not exercised'
 # Both axis editors may be open. Pending edits in one must survive updates
 # from the other, and unchanged stale fields must never revert newer units.
 [MathomirUiProbe]::Mouse($view,512,0,400,220);$dock=OpenDock 33116;Field $dock 1670 't'
 $inline=OpenAxes;Field $inline 1714 ('m/s'+[char]0x00B2);Press $inline 1715;Press $dock 1674
 $s=AxesSaved '74' '' '79' '6D2F73C2B2';Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($dock,1673)) -eq ('m/s'+[char]0x00B2)) 'Shared axis fields did not refresh'
 $inline=OpenAxes;Field $inline 1712 's';Field $dock 1672 'v';Press $dock 1674;Press $inline 1715
 $s=AxesSaved '74' '73' '76' '6D2F73C2B2';Capture 'feature-audit-shared-axes.png'
 # Repositioning an unchanged inline editor must not issue repeated child
 # layouts on every paint or lifetime timer tick.
 $inline=OpenAxes;$before=@(Get-Content (Join-Path $folder 'feature-audit-diagnostics.txt')|Where-Object{$_ -like 'axis editor layout*'}).Count
 for($i=0;$i -lt 25;$i++){[FeatureAuditProbe]::Paint($view)}
 $after=@(Get-Content (Join-Path $folder 'feature-audit-diagnostics.txt')|Where-Object{$_ -like 'axis editor layout*'}).Count;Check ($after -eq $before) 'Unchanged graph editor repeats child-window layout';Press $inline 1716
 # Idle polling is slower; actual animation retains the fast cadence.
 Press $dock 2;[MathomirUiProbe]::Send($main,273,33108)|Out-Null;Start-Sleep -Milliseconds 180;$slider=[MathomirUiProbe]::Child($view,33108)
 $lines=Get-Content (Join-Path $folder 'feature-audit-diagnostics.txt');Check (($lines|Where-Object{$_ -like 'slider interval*'}|Select-Object -Last 1) -eq 'slider interval 125') 'Idle sliders still poll at animation cadence'
 Press $slider 1570;Start-Sleep -Milliseconds 220;Press $slider 1570;$lines=Get-Content (Join-Path $folder 'feature-audit-diagnostics.txt');Check (@($lines|Where-Object{$_ -eq 'slider interval 16'}).Count -gt 0 -and ($lines|Where-Object{$_ -like 'slider interval*'}|Select-Object -Last 1) -eq 'slider interval 125') 'Play/pause did not switch polling cadence';Press $slider 2
 # Table plot options share the same axis model, and a removed update target
 # must not silently turn into a new graph.
 $null=SaveDoc;$file=Join-Path $folder 'feature-audit-table-target.mom';'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $file -Encoding ascii;[MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400
 $dock=OpenDock 33117;Field $dock 1630 "x`ty`r`n0`t1`r`n1`t3";Press $dock 1638;Click 100 100;EscapeView;$s=SaveDoc;Check ($s.SelectNodes('//datum').Count -eq 2) 'Audit table graph did not place'
 [MathomirUiProbe]::Mouse($view,512,0,300,220);$dock=OpenDock 33117;$inline=OpenAxes;Field $inline 1712 's';Press $inline 1715;Press $dock 1638
 $null=AxesSaved '78' '73' '79' '';[MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null;[MathomirUiProbe]::DeleteKey($view);Start-Sleep -Milliseconds 180;Check ((SaveDoc).mathomir.ChildNodes.Count -eq 0) 'Could not remove the audit table graph'
 Press $dock 1638;EscapeView;Check ((SaveDoc).mathomir.ChildNodes.Count -eq 0) 'Removed table-plot target silently created another graph';Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($dock,1640)) -like '*removed*') 'Missing table target has no clear status';Press $dock 2
 # The Spotlight overlay must release its temporary pens on every frame.
 [MathomirUiProbe]::Send($main,273,33121)|Out-Null
 for($i=0;$i -lt 20;$i++){[MathomirUiProbe]::Mouse($view,512,0,(200+$i),200);[FeatureAuditProbe]::Paint($view)}
 $gdi=[FeatureAuditProbe]::Gdi($app.Id);Check ($gdi -gt 0) 'Cannot measure Windows graphics resources'
 for($i=0;$i -lt 120;$i++){[MathomirUiProbe]::Mouse($view,512,0,(180+$i%140),(180+$i%90));[FeatureAuditProbe]::Paint($view)}
 $growth=[long][FeatureAuditProbe]::Gdi($app.Id)-$gdi;Check ($growth -le 20) "Spotlight redraw leaked $growth GDI objects";EscapeView
 Write-Output "Feature audit passed: one shared walk and one graph checksum per pass for 12 linked tables, merged simultaneous axis edits including table options, removed-target guard, stable editor layout, idle/active slider cadence, and 120 Spotlight redraws (GDI growth $growth)."
}catch{if($main){Capture 'feature-audit-failure.png'};throw}finally{if($app -and !$app.HasExited){Stop-Process -Id $app.Id -Force};Remove-Item Env:MATHOMIR_FEATURE_DIAGNOSTICS -ErrorAction SilentlyContinue;Remove-Item Env:MATHOMIR_GRAPH_DIAGNOSTICS -ErrorAction SilentlyContinue}
