$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$env:MATHOMIR_PRINT_GRID_CHECK='1'
$env:MATHOMIR_GRAPH_DIAGNOSTICS='1'
$grip=Get-Content (Join-Path $PSScriptRoot 'large-resize-grip-smoke.ps1') -Raw
$start=$grip.IndexOf("Add-Type @'")
Invoke-Expression $grip.Substring($start,$grip.IndexOf('$exe=')-$start).Replace('LargeGripProbe','CoordinateGripProbe').Replace('if(pixels[i]<30&&pixels[i+1]<30&&pixels[i+2]<30)return new int[]{x,y};','if((pixels[i]<30&&pixels[i+1]<30&&pixels[i+2]<30)||(pixels[i]>220&&pixels[i+1]<180&&pixels[i+2]<180)){bool line=true;for(int k=0;k<20;k++){int j=(y*width+x+k)*4;if(!((pixels[j]<30&&pixels[j+1]<30&&pixels[j+2]<30)||(pixels[j]>220&&pixels[j+1]<180&&pixels[j+2]<180))){line=false;break;}}if(line)return new int[]{x,y};}')
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $script:fixture -Raw)}
function Object($d){return $d.SelectSingleNode('/mathomir/*[self::o or self::obj][1]')}
function Model($d){return (Object $d).SelectSingleNode('./axesgrid[@role="1"]')}
function Axes($d){$o=Object $d;foreach($ink in $o.SelectNodes('./dw | ./draw')){$points=@();if($ink.HasAttribute('d')){$px=0.;$py=0.;foreach($s in $ink.d.Split('|')[1].Split(';')){$xy=$s.Split(',');if($xy[0] -ne ':'){$px=[double]$xy[0]};if($xy[1] -ne ':'){$py=[double]$xy[1]};$points+=,@(($px/32),($py/32))}}else{for($n=1;$ink.HasAttribute('X'+$n);$n++){$points+=,@(([double]$ink.GetAttribute('X'+$n)/1000),([double]$ink.GetAttribute('Y'+$n)/1000))}};for($n=1;$n -lt $points.Count;$n++){[pscustomobject]@{x1=[double]$o.X+$points[$n-1][0];y1=[double]$o.Y+$points[$n-1][1];x2=[double]$o.X+$points[$n][0];y2=[double]$o.Y+$points[$n][1]}}}}
function SameAxes($before,$after){$a=@(Axes $before);$b=@(Axes $after);Check ($a.Count -eq 6 -and $b.Count -eq 6) 'Coordinate axes lost their six original strokes';for($i=0;$i -lt 6;$i++){foreach($k in @('x1','y1','x2','y2')){Check ([Math]::Abs($a[$i].$k-$b[$i].$k) -lt .04) ('Axis moved while editing grid: '+$i+'/'+$k)}}}
function OpenEditor {
 [MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33103,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 50;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($app.Id,'Coordinate axes: grid and labels');if($d -ne [IntPtr]::Zero){Start-Sleep -Milliseconds 100;return $d}}
 throw 'Coordinate grid editor did not open'
}
function CloseEditor($d,$apply){[MathomirUiProbe]::PostMessage($d,273,[IntPtr]$(if($apply){1}else{2}),[IntPtr]::Zero)|Out-Null;for($i=0;$i -lt 50;$i++){Start-Sleep -Milliseconds 100;if(![MathomirUiProbe]::IsWindowVisible($d)){return}};throw 'Coordinate editor did not close'}
function SetValue($d,$id,$text){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,$id),[string]$text);Start-Sleep -Milliseconds 30}
function Choose($d,$id,$value){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,$id),334,$value)|Out-Null;[MathomirUiProbe]::Send($d,273,((1-shl 16)-bor $id))|Out-Null}
function Box($d,$id,$value){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,$id),241,$value)|Out-Null;[MathomirUiProbe]::Send($d,273,$id)|Out-Null}
function Capture($h,$file){Add-Type -AssemblyName System.Drawing;$r=[MathomirUiProbe]::WindowRect($h);$im=New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[System.Drawing.Graphics]::FromImage($im);$g.CopyFromScreen($r.Left,$r.Top,0,0,$im.Size);$im.Save($file);$g.Dispose();$im.Dispose()}
function Signature($h){Add-Type -AssemblyName System.Drawing;$r=[MathomirUiProbe]::WindowRect($h);$im=New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[System.Drawing.Graphics]::FromImage($im);$g.CopyFromScreen($r.Left,$r.Top,0,0,$im.Size);$hash=[long]17;for($y=3;$y -lt $im.Height-3;$y+=3){for($x=3;$x -lt $im.Width-3;$x+=3){$hash=($hash*31+$im.GetPixel($x,$y).ToArgb())%1000000007}};$g.Dispose();$im.Dispose();return $hash}
function Scene($suffix,$corner=$false,$legacy=$false){
 $script:fixture=Join-Path (Split-Path $exe) ('coordinate-axes-'+$suffix+'.mom')
 $v=if($corner){0}else{160};$h=if($corner){280}else{140}
 $shape='<dw d="64|'+($v*32)+',0;'+($v*32)+',8960" /><dw d="64|'+($v*32)+',0;'+(($v+4)*32)+',256" /><dw d="64|'+($v*32)+',0;'+(($v-4)*32)+',256" /><dw d="64|0,'+($h*32)+';10240,'+($h*32)+'" /><dw d="64|10240,'+($h*32)+';9984,'+(($h+4)*32)+'" /><dw d="64|10240,'+($h*32)+';9984,'+(($h-4)*32)+'" />'
 $old='';if($legacy){foreach($x in @(64,96,128,192,224,256)){$old+='<dw d="16|'+($x*32)+',0;'+($x*32)+',8960" />'};foreach($y in @(44,76,108,172,204,236)){$old+='<dw d="16|0,'+($y*32)+';10240,'+($y*32)+'" />'}}
 ('<?xml version="1.0"?><mathomir><o t="2" X="100" Y="100">'+$old+$shape+'</o></mathomir>')|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250;[MathomirUiProbe]::Send($view,273,32775)|Out-Null
}
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'Application did not start';$view=[MathomirUiProbe]::Child($main,0xE900)
 Check ([MathomirUiProbe]::MenuText($main,33103).Contains('axis labels')) 'Draw menu lacks the coordinate editor'
 Scene 'trig';$before=SaveDoc;$baseline=(Object $before).OuterXml
 # In the instrumented build, discover and click the actual coordinate context row.
 $row=Join-Path (Split-Path $exe) 'coordinate-axes-menu.txt';Remove-Item $row -ErrorAction SilentlyContinue
 [MathomirUiProbe]::Mouse($view,512,0,260,240);[MathomirUiProbe]::Mouse($view,516,2,260,240);[MathomirUiProbe]::Mouse($view,517,0,260,240);Start-Sleep -Milliseconds 100
 if(Test-Path $row){$p=(Get-Content $row -Raw).Split(' ');$popup=[MathomirUiProbe]::Window($app.Id,'PopupMenu');Check ($popup -ne [IntPtr]::Zero) 'Coordinate context menu not visible';[MathomirUiProbe]::Mouse($popup,512,0,[int]$p[0],[int]$p[1]);[MathomirUiProbe]::PostMessage($popup,513,[IntPtr]1,[IntPtr](([int]$p[1]-shl 16)-bor [int]$p[0]))|Out-Null;for($i=0;$i -lt 50;$i++){Start-Sleep -Milliseconds 100;$dialog=[MathomirUiProbe]::Window($app.Id,'Coordinate axes: grid and labels');if($dialog -ne [IntPtr]::Zero){break}};Check ($dialog -ne [IntPtr]::Zero) 'Actual context grid row failed to open the editor'}else{[MathomirUiProbe]::Send($view,258,27)|Out-Null;$dialog=OpenEditor}
 foreach($id in @(1459,1461,1463,1465)){Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($dialog,$id)).Length -ge 1) 'A Unicode editor input was not populated'}
 # Cancel must preserve the document exactly, including its original axes.
 SetValue $dialog 1450 '36';CloseEditor $dialog $false;$cancel=SaveDoc;Check ((Object $cancel).OuterXml -eq $baseline) 'Cancel changed the coordinate drawing'
 $dialog=OpenEditor
 foreach($bad in @('0','-4','nan','')){SetValue $dialog 1450 $bad;Check (![MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($dialog,1))) ('Invalid cell spacing accepted: '+$bad)}
 SetValue $dialog 1450 '40';SetValue $dialog 1452 '101';Check (![MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($dialog,1))) 'Invalid darkness accepted';SetValue $dialog 1452 '22'
 foreach($bad in @('x+1','1/0','sqrt(-1)','0')){SetValue $dialog 1459 $bad;Check (![MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($dialog,1))) ('Invalid label increment accepted: '+$bad)}
 [MathomirUiProbe]::Send($dialog,273,1474)|Out-Null;SetValue $dialog 1452 '22';SetValue $dialog 1453 '65';SetValue $dialog 1454 '2';SetValue $dialog 1461 ([string][char]0x03b8);Choose $dialog 1455 1
 Check ([MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($dialog,1))) 'Valid trig settings left Apply disabled'
 Start-Sleep -Milliseconds 150;$preview=[MathomirUiProbe]::Child($dialog,1471);$light=Signature $preview;SetValue $dialog 1452 '85';Start-Sleep -Milliseconds 150;$dark=Signature $preview;Check ($light -ne $dark) 'Preview ignores grid darkness';SetValue $dialog 1452 '22'
 Choose $dialog 1456 1;Start-Sleep -Milliseconds 150;$dash=Signature $preview;Choose $dialog 1456 2;Start-Sleep -Milliseconds 150;$dot=Signature $preview;Check ($dash -ne $dot) 'Dashed and dotted previews are identical';Choose $dialog 1456 0
 Capture $dialog (Join-Path (Split-Path $exe) 'coordinate-axes-editor-ui.png')
 CloseEditor $dialog $true;$trig=SaveDoc;SameAxes $before $trig;$m=Model $trig;Check ($m -ne $null -and $m.sx -eq '40' -and $m.sy -eq '40' -and $m.minor -eq '22' -and $m.majorDark -eq '65' -and $m.xf -eq '2') 'Trig/grid settings were not saved'
 Check ((Object $trig).SelectNodes('.//var[@t="p"][@f="60"] | .//elm[@tp="1"][@tx="p"][@fnt="60"]').Count -gt 0) 'Radians did not generate native pi labels'
 Check ((Object $trig).SelectNodes('.//fra | .//elm[@tp="4"]').Count -gt 0) 'Radians did not generate native fractions'
 Check ((Object $trig).SelectNodes('.//var[@t="q"][@f="60"] | .//elm[@tp="1"][@tx="q"][@fnt="60"]').Count -gt 0) 'Greek theta axis name did not generate native math'
 # Reopen to leave selection mode; hover a long axis stroke rather than an embedded label.
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250
 # Resize a configured grid using the visible native grip, then reopen its settings.
 [MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null
 [MathomirUiProbe]::Mouse($view,512,0,40,40);[MathomirUiProbe]::Mouse($view,513,1,40,40);[MathomirUiProbe]::Mouse($view,514,0,40,40);Start-Sleep -Milliseconds 150
 $r=[MathomirUiProbe]::ClientRect($view);$ink=[CoordinateGripProbe]::FindInk($view,$r.Right,$r.Bottom);[MathomirUiProbe]::Mouse($view,512,0,$ink[0],$ink[1]);Start-Sleep -Milliseconds 100;$gr=[CoordinateGripProbe]::Find($view,$r.Right,$r.Bottom)
 [MathomirUiProbe]::Mouse($view,512,0,$gr[0],$gr[1]);[MathomirUiProbe]::Mouse($view,513,1,$gr[0],$gr[1]);[MathomirUiProbe]::Mouse($view,512,1,($gr[0]+65),($gr[1]+45));[MathomirUiProbe]::Mouse($view,514,0,($gr[0]+65),($gr[1]+45));$grown=SaveDoc
 Check ([double](Model $grown).sx -gt 40 -and [double](Model $grown).sy -gt 40) 'Resizing did not scale saved cell spacing'
 Check ((Model $grown).xv -eq (Model $trig).xv) 'Resizing changed numeric values per cell'
 $dialog=OpenEditor;Check ([Math]::Abs([double][MathomirUiProbe]::Text([MathomirUiProbe]::Child($dialog,1450))-[double](Model $grown).sx) -lt .001) 'Resized spacing did not load into the editor';CloseEditor $dialog $false
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$restored=SaveDoc;Check ((Object $restored).OuterXml -eq (Object $trig).OuterXml) 'Resize Undo did not restore the configured grid'
 $saved=(Object $trig).OuterXml;[MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250;$reload=SaveDoc;Check ((Object $reload).OuterXml -eq $saved) 'Grid and labels changed after reopening'
 $dialog=OpenEditor;Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($dialog,1461)) -eq [string][char]0x03b8) 'Greek name did not reload into the editor';Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($dialog,1459)) -eq 'pi/2') 'Trig step was lost on reopening';SetValue $dialog 1450 '32';SetValue $dialog 1451 '24';SetValue $dialog 1452 '40';CloseEditor $dialog $true;$edited=SaveDoc;SameAxes $trig $edited;Check ((Model $edited).sx -eq '32' -and (Model $edited).sy -eq '24') 'Existing grid spacing could not be changed'
 Check ((Object $edited).SelectNodes('./group | ./gr').Count -eq 1) 'Editing duplicated the generated grid'
 [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$undo=SaveDoc;Check ((Object $undo).OuterXml -eq $saved) 'Undo did not restore the grid and native labels'
 # Other common formats must produce true native notation, rather than raw strings.
 foreach($case in @(@{name='fraction';format=1;value='1/3'},@{name='degree';format=3;value='30'},@{name='scientific';format=4;value='0.001'})){
  Scene $case.name;$raw=SaveDoc;$dialog=OpenEditor;Choose $dialog 1458 $case.format;SetValue $dialog 1459 $case.value;SetValue $dialog 1450 '48';SetValue $dialog 1451 '48';CloseEditor $dialog $true;$d=SaveDoc;SameAxes $raw $d;Check ((Model $d).xf -eq [string]$case.format) ('Format lost: '+$case.name)
  if($case.format -eq 1){Check ((Object $d).SelectNodes('.//fra | .//elm[@tp="4"]').Count -gt 0) 'Fraction format did not create native fraction elements'}
  if($case.format -eq 4){Check ((Object $d).SelectNodes('.//elm[@tp="3"]').Count -gt 0) 'Scientific format did not create native powers of ten'}
 }
 foreach($kind in @(@{name='corner';corner=$true;legacy=$false},@{name='legacy';corner=$false;legacy=$true})){
  Scene $kind.name $kind.corner $kind.legacy;$raw=SaveDoc;$dialog=OpenEditor;SetValue $dialog 1450 '36';SetValue $dialog 1451 '28';Box $dialog 1476 0;CloseEditor $dialog $true;$d=SaveDoc
  if(!$kind.legacy){SameAxes $raw $d};Check ((Model $d).grid -eq '0') 'Grid could not be hidden';$without=@();foreach($mode in 1..3){$without+=[MathomirUiProbe]::Send($view,32923,$mode,1)};$dialog=OpenEditor;Box $dialog 1476 1;CloseEditor $dialog $true;$d=SaveDoc;Check ((Model $d).grid -eq '1') 'Grid could not be restored after hiding';foreach($mode in 1..3){$printed=[MathomirUiProbe]::Send($view,32923,$mode,1);Check ($printed -gt $without[$mode-1]+100) ('Coordinate grid missing from actual print/preview path '+$mode)}
 }
 Write-Output 'Coordinate editor passed: actual context/menu route, preview contrast and styles, independent spacing and units, native negative pi/fraction/scientific labels, Greek names, Cancel, save/reopen, existing-grid editing, no duplicates, Undo, corner axes, legacy grids, native grip resizing and actual print/preview at 100/50 percent.'
}finally{
 if($main -ne [IntPtr]::Zero -and !$app.HasExited){Capture $main (Join-Path (Split-Path $exe) 'coordinate-axes-canvas-ui.png')}
 $app.Refresh();if(!$app.HasExited){$app.Kill();$app.WaitForExit()};Remove-Item Env:MATHOMIR_PRINT_GRID_CHECK,Env:MATHOMIR_GRAPH_DIAGNOSTICS -ErrorAction SilentlyContinue
}
