$ErrorActionPreference='Stop'
$baseHelpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $baseHelpers.Substring(0,$baseHelpers.IndexOf('$exe ='))
$shared=Get-Content (Join-Path $PSScriptRoot 'interactive-features-smoke.ps1') -Raw
$helperStart=$shared.IndexOf('Add-Type -AssemblyName System.Drawing')
Invoke-Expression $shared.Substring($helperStart,$shared.IndexOf('$exe=')-$helperStart)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TeachingUI {
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageW")] static extern IntPtr SendText(IntPtr h,uint m,IntPtr wp,string s);
 [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc,int x,int y);
 public static int FindList(IntPtr h,string text){return SendText(h,0x1A2,(IntPtr)(-1),text).ToInt32();}
 public static int[] PointA(IntPtr view){IntPtr dc=GetDC(view);long xsum=0,ysum=0;int n=0;try{for(int y=125;y<520;y++)for(int x=135;x<620;x++){if(GetPixel(dc,x,y)==0xAF5F19){xsum+=x;ysum+=y;n++;}}}finally{ReleaseDC(view,dc);}if(n<15)throw new Exception("Graph point A is not painted");return new[]{(int)(xsum/n),(int)(ysum/n),n};}
}
'@
$caseFailures=New-Object 'System.Collections.Generic.List[string]'
function Case($name,[scriptblock]$body){try{& $body}catch{$why=$_.Exception.Message;$caseFailures.Add($name+': '+$why);if($main -ne [IntPtr]::Zero){Capture $main ('teaching-case-'+($name -replace '[^a-zA-Z0-9]','-')+'.png')};Write-Output ('TEACHING CASE FAILED: '+$name+': '+$why)}}
function Dock($command){Command $command;for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 50;$p=[MathomirUiProbe]::Child($view,33116);if($p -ne [IntPtr]::Zero -and [MathomirUiProbe]::IsWindowVisible($p)){return $p}};throw 'Teaching dock did not appear'}
function Press($p,$id){[MathomirUiProbe]::Send($p,273,$id)|Out-Null;Start-Sleep -Milliseconds 150}
function SelectChoice($p,$id,$index){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($p,$id),334,$index)|Out-Null;[MathomirUiProbe]::Send($p,273,((1-shl 16)-bor $id))|Out-Null}
function SelectList($p,$id,$index){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($p,$id),390,$index)|Out-Null;[MathomirUiProbe]::Send($p,273,((1-shl 16)-bor $id))|Out-Null}
function Mark($p,$id,$value){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($p,$id),241,[int]$value)|Out-Null}
function Decode($hex){if(!$hex){return ''};$bytes=for($i=0;$i -lt $hex.Length;$i+=2){[Convert]::ToByte($hex.Substring($i,2),16)};return [Text.Encoding]::UTF8.GetString([byte[]]$bytes)}
function EscapeView {[MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null;Start-Sleep -Milliseconds 100}
function NewRelation {Load 'teaching-curve' '<?xml version="1.0"?><mathomir></mathomir>';$d=Dialog 33106 'Relations and parametric curves';SetField $d 1423 'y=a*x^2';[MathomirUiProbe]::Send($d,273,1439)|Out-Null;CloseDialog $d;Place 100 100}
function NativeTable($rows){$xml='<?xml version="1.0"?><mathomir><obj type="1" X="100" Y="180"><ex><elm tp="5" E1=""><ex shp=" ">';foreach($row in $rows){$xml+='<var t="'+$row[0]+'" f="00"/><col_sep/><var t="'+$row[1]+'" f="00"/><row_sep/>'};return $xml+'</ex></elm></ex></obj></mathomir>'}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe
$env:MATHOMIR_PLACEMENT_DIAGNOSTICS='1';$env:MATHOMIR_DIAGNOSTIC_STARTUP='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start';[InteractiveUI]::ShowWindow($main,3)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 Case 'graph points and links' {
 NewRelation;$d=Dock 33116;Check ([InteractiveUI]::GetParent($d) -eq $view -and ([InteractiveUI]::Style($d,-16)-band 0x40000000)) 'Teaching controls are not embedded in the canvas';Check ([MathomirUiProbe]::IsWindowEnabled($main)) 'Teaching controls disabled the page'
 SetField $d 1670 't';SetField $d 1671 's';SetField $d 1672 'v';SetField $d 1673 ('m/s'+[char]0x00B2);Press $d 1674;$s=SaveDoc;$axis=$s.SelectSingleNode('//graphaxes');Check ((Decode $axis.xn) -eq 't' -and (Decode $axis.yu) -eq ('m/s'+[char]0x00B2)) 'Graph units were lost'
 Mark $d 1617 $true;Mark $d 1614 $true;Mark $d 1615 $true;Mark $d 1616 $true;SetField $d 1612 .5;SetField $d 1613 1.5;Press $d 1618;Start-Sleep -Milliseconds 300;$s=SaveDoc;$e=$s.SelectSingleNode('//explore');Check ([double]$e.a -eq .5 -and $e.tangent -eq '1' -and $e.normal -eq '1' -and $e.secant -eq '1') 'Point/tangent settings were not applied';$point=[TeachingUI]::PointA($view);Capture $main 'teaching-points-units.png'
 [InteractiveUI]::Drag($main,$view,$point[0],$point[1],($point[0]+45),$point[1]);$moved=SaveDoc;Check ([Math]::Abs([double]$moved.SelectSingleNode('//explore').a-.5) -gt .05) 'Dragging A did not move it along the curve';Command 0xE12B;$s=SaveDoc;Check ([Math]::Abs([double]$s.SelectSingleNode('//explore').a-.5) -lt 1e-7) 'Undo did not restore A'
 $d=Dock 33116;SetField $d 1620 0;SetField $d 1621 1;SetField $d 1622 5;Press $d 1619;Place 100 500;$s=SaveDoc;Check ($s.SelectNodes('//ex[@tgraph] | //expr[@tgraph]').Count -eq 1) 'Linked value table was not created';$linked=$s.SelectSingleNode('//ex[@tgraph] | //expr[@tgraph]');Check ($linked.OuterXml -match '16') 'Linked table did not evaluate the curve'
 $d=Panel;SetField $d 1511 2;Press $d 1501;Start-Sleep -Milliseconds 350;$s=SaveDoc;$linked=$s.SelectSingleNode('//ex[@tgraph] | //expr[@tgraph]');Check ($linked.OuterXml -match '32') 'Slider change did not update the linked table';ClosePanel $d;Reopen 'teaching-linked-reopened';$s=SaveDoc;Check ($s.SelectNodes('//graphaxes').Count -eq 1 -and $s.SelectNodes('//explore').Count -eq 1 -and $s.SelectNodes('//ex[@tgraph] | //expr[@tgraph]').Count -eq 1) 'Units, points or linked table did not reopen'
 $d=Panel;$before=[double](SaveDoc).SelectSingleNode('//sliders').a;SetField $d 1572 1;SelectChoice $d 1573 2;Press $d 1570;Start-Sleep -Milliseconds 400;$playing=[double][MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1511));Check ([Math]::Abs($playing-$before) -gt .1) 'Animation did not move the slider';Press $d 1570;$paused=[double][MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1511));Start-Sleep -Milliseconds 250;Check ([double][MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1511)) -eq $paused) 'Pause kept changing values';Command 0xE12B;Check ([Math]::Abs([double](SaveDoc).SelectSingleNode('//sliders').a-$before) -lt 1e-7) 'Animation did not form one Undo gesture';Capture $main 'teaching-animation.png';ClosePanel $d
 Write-Output 'Graph teaching passed: embedded controls, Unicode units, points, tangent/normal/secant, real drag, Undo, linked table updates, animation/pause/Undo, save and reopen.'
 }
 Case 'tables' {
 # Pasted tables support arbitrary variable names and units without fitting a regression.
 Load 'teaching-data' '<?xml version="1.0"?><mathomir></mathomir>';$d=Dock 33117;SetField $d 1630 "t`tv`n0`t1`n1`t3`n2`t6`n3`t10";SetField $d 1643 's';SetField $d 1644 ('m/s'+[char]0x00B2);Mark $d 1636 $true;Press $d 1642;Capture $main 'teaching-table-preview.png';Press $d 1638;Place 100 100;$s=SaveDoc;Check ($s.SelectNodes('//datum').Count -eq 4 -and $s.SelectSingleNode('//plotdata').connect -eq '1') 'Table did not plot four connected pairs';Check ((Decode $s.SelectSingleNode('//graphaxes').xn) -eq 't' -and (Decode $s.SelectSingleNode('//graphaxes').yu) -eq ('m/s'+[char]0x00B2)) 'Table variables and units did not persist';Capture $main 'teaching-table-plotted.png';Reopen 'teaching-data-reopened';$d=Dock 33117;Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1644)) -eq ('m/s'+[char]0x00B2)) 'Reopened table plot cannot edit its units';ClosePanel $d
 # Invalid rows cannot place an old preview; rows can be used as the two series.
 Load 'teaching-bad-data' '<?xml version="1.0"?><mathomir></mathomir>';$d=Dock 33117;SetField $d 1630 "1,2`n2,";Press $d 1638;Check ([MathomirUiProbe]::IsWindowVisible($d) -and (SaveDoc).mathomir.ChildNodes.Count -eq 0) 'Incomplete data silently placed a stale plot';SetField $d 1630 "t`t0`t1`t2`nv`t4`t8`t13";SelectChoice $d 1633 1;Press $d 1642;Press $d 1638;Place 100 100;$s=SaveDoc;Check ($s.SelectNodes('//datum').Count -eq 3 -and [double]$s.SelectNodes('//datum')[2].y -eq 13) 'Two-row table did not plot the chosen series'
 # Existing native tables can be selected, linked and refreshed after editing their cells.
 Load 'teaching-native-table' (NativeTable @(@('t','v'),@('0','1'),@('1','3'),@('2','6')));PickObjects 1;$d=Dock 33117;Press $d 1637;Press $d 1642;Press $d 1638;Place 350 100;$s=SaveDoc;Check ($s.SelectNodes('//datum').Count -eq 3 -and [int]$s.SelectSingleNode('//plotdata').source -gt 0) 'Selected native table was not linked to its plot';$vars=$s.SelectNodes('//var[@t="6"] | //elm[@tx="6"]');Check ($vars.Count -gt 0) 'Native source table lost its cells';foreach($v in $vars){if($v.HasAttribute('t')){$v.SetAttribute('t','9')}else{$v.SetAttribute('tx','9')}};$s.Save($fixture);Reopen 'teaching-native-table-edited';$updated=SaveDoc;Check ([double]$updated.SelectNodes('//datum')[2].y -eq 9) 'Editing source cells did not refresh the plot';Capture $main 'teaching-native-table-linked.png'
 Write-Output 'Table plotting passed: pasted columns, Unicode units, connected points, preview, saved editing, incomplete-row rejection, row series, native tables and source-cell refresh.'
 }
 Case 'objects' {
 # Layer controls reach buried roots, preserving names, visibility and existing native locks.
 $xml='<?xml version="1.0"?><mathomir><obj type="1" X="120" Y="220"><ex><var t="FIRST" f="00"/></ex></obj><obj type="1" X="120" Y="220"><ex><var t="SECOND" f="00"/></ex></obj></mathomir>';Load 'teaching-objects' $xml;$d=Dock 33118;SelectList $d 1650 0;SetField $d 1651 'Top note';Press $d 1652;$s=SaveDoc;Check ($s.SelectNodes('//ex[@oname] | //expr[@oname]').Count -eq 1) 'Object rename not saved';Press $d 1653;$s=SaveDoc;Check ($s.SelectSingleNode('//ex[@oname] | //expr[@oname]').hidden -eq '1') 'Hidden object flag lost';Press $d 1653;Press $d 1654;$s=SaveDoc;Check ($s.SelectNodes('/mathomir/*[@lock="1"]').Count -eq 1) 'Native object lock not saved';Press $d 1654;Press $d 1656;$s=SaveDoc;Check ($s.mathomir.ChildNodes[0].SelectSingleNode('./ex[@oname] | ./expr[@oname]')) 'Send backward did not reorder the selected identity';Press $d 1655;Capture $main 'teaching-objects-panel.png';ClosePanel $d
 }
 Case 'palette' {
 # Reusable items remain native and receive independent identities at placement.
 Load 'teaching-palette' '<?xml version="1.0"?><mathomir><obj type="1" X="120" Y="220"><ex><var t="SAVED" f="00"/></ex></obj></mathomir>';PickObjects 1;$d=Dock 33119;$name='Teaching smoke '+[DateTime]::UtcNow.Ticks;SetField $d 1661 $name;Press $d 1662;$index=[TeachingUI]::FindList([MathomirUiProbe]::Child($d,1660),$name);Check ($index -ge 0) 'Selection was not saved to the reusable palette';SelectList $d 1660 $index;Capture $main 'teaching-reusable-palette.png';$count=(SaveDoc).mathomir.ChildNodes.Count;Press $d 1663;Place 350 350;$s=SaveDoc;Check ($s.mathomir.ChildNodes.Count -eq $count+1) 'Reusable item did not place an independent copy';$ids=@($s.SelectNodes('//*[@oid]')|ForEach-Object {$_.oid});Check (($ids|Sort-Object -Unique).Count -eq $ids.Count) 'Reusable copy kept duplicate object identities';$d=Dock 33119;$index=[TeachingUI]::FindList([MathomirUiProbe]::Child($d,1660),$name);Check ($index -ge 0) 'Saved palette item disappeared when reopened';SelectList $d 1660 $index;Press $d 1664;ClosePanel $d
 Write-Output 'Object tools passed: buried selection, rename, hide/show, native lock/unlock, order, editable reusable copies and independent identities.'
 }
 Case 'alignment and presentation' {
 # Alignment, equal spacing and presentation overlays use the real page.
 $xml='<?xml version="1.0"?><mathomir><obj type="2" X="100" Y="160"><dw d="32|0,0;2560,0;2560,1600;0,1600;0,0"/></obj><obj type="2" X="310" Y="230"><dw d="32|0,0;2560,0;2560,1600;0,1600;0,0"/></obj><obj type="2" X="550" Y="310"><dw d="32|0,0;2560,0;2560,1600;0,1600;0,0"/></obj></mathomir>';Load 'teaching-alignment' $xml;PickObjects 7;Command 33124;$s=SaveDoc;$ys=@($s.mathomir.ChildNodes|ForEach-Object {$_.Y});Check (($ys|Sort-Object -Unique).Count -eq 1) 'Top alignment ignored the selection';Command 0xE12B;PickObjects 7;Command 33125;$s=SaveDoc;$xs=@($s.mathomir.ChildNodes|ForEach-Object {[double]$_.X});Check ([Math]::Abs(($xs[1]-$xs[0])-($xs[2]-$xs[1])) -le 1) 'Horizontal spacing is uneven';Command 33120;Capture $main 'teaching-alignment.png';Command 33120
 $before=(SaveDoc).OuterXml;$normal=[InteractiveUI]::Frame($view)[0];Command 33121;[MathomirUiProbe]::Mouse($view,512,0,350,300);Start-Sleep -Milliseconds 100;$lit=[InteractiveUI]::Frame($view)[0];Check ($lit -ne $normal) 'Spotlight overlay did not render';Capture $main 'teaching-spotlight.png';EscapeView;Command 33122;[MathomirUiProbe]::Mouse($view,512,0,320,260);Start-Sleep -Milliseconds 100;$lens=[InteractiveUI]::Frame($view)[0];Check ($lens -ne $normal) 'Magnifier did not render';Capture $main 'teaching-magnifier.png';EscapeView;Check ((SaveDoc).OuterXml -eq $before) 'Presentation overlay changed the saved document'
 Write-Output 'Alignment and presentation passed: edge alignment, equal spacing, spotlight, magnifier, Escape and unchanged authored content.'
 }
 Case 'lifecycle' {
 # Opening another document disconnects the dock; no control can modify an old object.
 $d=Dock 33116;Load 'teaching-empty-final' '<?xml version="1.0"?><mathomir></mathomir>';Check (![MathomirUiProbe]::IsWindowVisible($d)) 'Old teaching dock remained bound across documents';Check (!(SaveDoc).SelectSingleNode('//explore | //plotdata | //graphaxes')) 'Old graph metadata leaked into a new document'
 }
 if($caseFailures.Count){throw ('Teaching cases failed: '+($caseFailures -join '; '))}
 Write-Output 'Teaching tools native Windows checks passed.'
}catch{if($main -ne [IntPtr]::Zero){Capture $main 'teaching-failure.png'};throw}finally{if($app -and !$app.HasExited){Stop-Process -Id $app.Id -Force};Remove-Item Env:MATHOMIR_PLACEMENT_DIAGNOSTICS -ErrorAction SilentlyContinue;Remove-Item Env:MATHOMIR_DIAGNOSTIC_STARTUP -ErrorAction SilentlyContinue}
