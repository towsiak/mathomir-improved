$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $script:fixture -Raw)}
function Root($d){return $d.SelectSingleNode('/mathomir/*[.//var[@t="MMMM"] or .//elm[@tx="MMMM"] or .//var[@t="e"] or .//elm[@tx="e"]]')}
function Label($d){return $d.SelectSingleNode('/mathomir/*[.//var[@t="note"] or .//elm[@tx="note"]]')}
function Scene($font,$power,$rootLast,$zoom,$suffix){
 $script:fixture=Join-Path (Split-Path $exe) ("enlarged-overlap-$font-$power-$rootLast-$zoom-$suffix.mom")
 $script:noteX=100+[int]($font*.14);$script:noteY=175
 $formula=if($power){'<elm tp="3" E1="" E2=""><ex fh="'+$font+'"><var t="e" f="00" /></ex><ex fh="'+[int]($font*.7)+'"><var t="2" f="00" /><var t="x" f="00" /></ex></elm>'}else{'<var t="MMMM" f="00" />'}
 $root='<o t="1" X="100" Y="190"><ex fh="'+$font+'">'+$formula+'</ex></o>'
 $note='<o t="1" X="'+$noteX+'" Y="175"><ex fh="100" stxt="1"><var t="note" f="00" color="1" /></ex></o>'
 $line='<o t="2" X="'+$noteX+'" Y="185"><dw d="32|0,0;800,0" /></o>'
 $objects=if($rootLast){$note+$line+$root}else{$root+$note+$line}
 ('<?xml version="1.0"?><mathomir>'+$objects+'</mathomir>')|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250
 [MathomirUiProbe]::Send($view,273,$(if($zoom -eq 60){32777}elseif($zoom -eq 200){33019}else{32775}))|Out-Null
 [MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
 Start-Sleep -Milliseconds 200
 $script:scale=$zoom/100.0;$d=SaveDoc;$script:rootXml=(Root $d).OuterXml
}
function DragAnnotation($x,$y){
 [MathomirUiProbe]::Mouse($view,512,0,[int](($x+12)*$scale),[int](($y-5)*$scale));Start-Sleep -Milliseconds 80
 $grip=[MathomirUiProbe]::MoveGripNear($view,([int]($x*$scale)-12),[int]($y*$scale)-12)
 [MathomirUiProbe]::Mouse($view,512,0,($grip[0]+10),($grip[1]+10));Start-Sleep -Milliseconds 60
 $stable=[MathomirUiProbe]::MoveGripNear($view,$grip[0],$grip[1]+15)
 Check ($stable[0] -eq $grip[0] -and $stable[1] -eq $grip[1]) 'Large text stole controls in the annotation approach gap'
 [MathomirUiProbe]::Mouse($view,512,0,$grip[0],$grip[1]);[MathomirUiProbe]::Mouse($view,513,1,$grip[0],$grip[1])
 $dx=[int](30*$scale);$dy=[int](20*$scale)
 [MathomirUiProbe]::Mouse($view,512,1,($grip[0]+$dx),($grip[1]+$dy));[MathomirUiProbe]::Mouse($view,514,0,($grip[0]+$dx),($grip[1]+$dy))
}
try {
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App failed to start';[MathomirUiProbe]::Send($main,274,0xF030)|Out-Null;$view=[MathomirUiProbe]::Child($main,0xE900)
 foreach($font in @(400,800)){foreach($power in @($false,$true)){foreach($rootLast in @($false,$true)){foreach($zoom in @(60,100,200)){
  Scene $font $power $rootLast $zoom 'label'
  DragAnnotation $noteX $noteY
  $d=SaveDoc;$label=Label $d
  Check ($label.X -eq [string]($noteX+30) -and $label.Y -eq '195') "Label drag failed: $font/$power/$rootLast/$zoom"
  Check ((Root $d).OuterXml -eq $rootXml) 'Selecting/moving the small label altered the enlarged expression'
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$d=SaveDoc;Check ((Label $d).X -eq [string]$noteX -and (Label $d).Y -eq '175') 'Label move Undo failed'
  # Grab the thin brace/line independently even while it overlaps the root's box.
  [MathomirUiProbe]::Mouse($view,512,0,[int](($noteX+15)*$scale),[int](185*$scale));Start-Sleep -Milliseconds 80
  $g=[MathomirUiProbe]::MoveGripNear($view,([int]($noteX*$scale)-12),[int](185*$scale)-12)
  [MathomirUiProbe]::Mouse($view,512,0,$g[0],$g[1]);[MathomirUiProbe]::Mouse($view,513,1,$g[0],$g[1]);[MathomirUiProbe]::Mouse($view,512,1,($g[0]+[int](30*$scale)),($g[1]+[int](20*$scale)));[MathomirUiProbe]::Mouse($view,514,0,($g[0]+[int](30*$scale)),($g[1]+[int](20*$scale)))
  $d=SaveDoc;$line=$d.SelectSingleNode('/mathomir/*[@t="2" or @type="2"]');Check ($line.X -eq [string]($noteX+30) -and $line.Y -eq '205') "Thin stroke drag failed: $font/$power/$rootLast/$zoom";Check ((Root $d).OuterXml -eq $rootXml) 'Stroke move changed the large equation'
 }}}}
 Scene 800 $true $true 100 'direct-label-edit'
 [MathomirUiProbe]::Mouse($view,512,0,500,300)
 [MathomirUiProbe]::Mouse($view,513,1,($noteX+15),($noteY-5));[MathomirUiProbe]::Mouse($view,514,0,($noteX+15),($noteY-5))
 [MathomirUiProbe]::Send($view,258,[int][char]'Z')|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null
 $d=SaveDoc;Check ((Root $d).OuterXml -eq $rootXml) 'Direct editing of the small annotation changed its large equation'
 $texts=($d.SelectNodes('//var | //elm[@tp="1"]')|ForEach-Object {if($_.HasAttribute('t')){$_.t}else{$_.tx}})-join ''
 Check ($texts.Contains('Z') -and $d.mathomir.ChildNodes.Count -eq 3) 'Direct click did not edit the existing small annotation'
 # A palette shape must survive a click on an existing object's move handle.
 Scene 800 $true $false 100 'placing-grip'
 [MathomirUiProbe]::Mouse($view,512,0,130,180);Start-Sleep -Milliseconds 100
 $g=[MathomirUiProbe]::MoveGripNear($view,88,50)
 [MathomirUiProbe]::Send($main,273,33059)|Out-Null
 [MathomirUiProbe]::Mouse($view,512,0,$g[0],$g[1]);[MathomirUiProbe]::Mouse($view,513,1,$g[0],$g[1]);[MathomirUiProbe]::Mouse($view,514,0,$g[0],$g[1]);[MathomirUiProbe]::Send($view,258,27)|Out-Null
 $d=SaveDoc;Check ($d.mathomir.ChildNodes.Count -eq 4) 'Existing grip consumed the pending palette object';Check ((Root $d).OuterXml -eq $rootXml) 'Palette placement moved/resized the underlying equation'
 # Shift-click keeps a palette expression independent even directly on a glyph.
 Scene 800 $true $false 100 'shift-expression'
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33089,[IntPtr]::Zero)|Out-Null
 $dialog=[IntPtr]::Zero;for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;$dialog=[MathomirUiProbe]::Window($app.Id,'Symbolic derivative finder');if($dialog -ne [IntPtr]::Zero){break}}
 Check ($dialog -ne [IntPtr]::Zero) 'Derivative palette expression source did not open'
 [MathomirUiProbe]::Send($dialog,273,1)|Out-Null;Start-Sleep -Milliseconds 150
 [MathomirUiProbe]::Mouse($view,512,0,130,180);[MathomirUiProbe]::Mouse($view,513,5,130,180);[MathomirUiProbe]::Mouse($view,514,4,130,180);[MathomirUiProbe]::Send($view,258,27)|Out-Null
 $d=SaveDoc;Check ($d.mathomir.ChildNodes.Count -eq 4) 'Shift placement inserted/replaced part of the enlarged expression';Check ((Root $d).OuterXml -eq $rootXml) 'Shift placement altered the underlying equation'
 # Standalone annotation via double-click also works inside the enlarged box.
 Scene 800 $true $false 100 'new-text'
 [MathomirUiProbe]::Mouse($view,512,0,($noteX+45),175);[MathomirUiProbe]::Mouse($view,515,1,($noteX+45),175);[MathomirUiProbe]::Mouse($view,514,0,($noteX+45),175)
 foreach($c in 'standalone'.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$c)|Out-Null};[MathomirUiProbe]::Send($view,258,27)|Out-Null
 $d=SaveDoc;Check ($d.mathomir.ChildNodes.Count -eq 4) 'Independent typing inside a power became part of the large equation';Check ((Root $d).OuterXml -eq $rootXml) 'Independent typing altered the large equation'
 Add-Type -AssemblyName System.Drawing;$rect=[MathomirUiProbe]::WindowRect($main);$image=New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top);$graphics=[System.Drawing.Graphics]::FromImage($image);$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$image.Size);$image.Save((Join-Path (Split-Path $exe) 'enlarged-overlap-ui.png'));$graphics.Dispose();$image.Dispose()
 Write-Output 'Enlarged overlap passed: 400/800 percent fonts, text and nested powers, both creation orders, 60/100/200 percent zoom, label/stroke grips and approach gaps, root preservation, Undo, palette placement over controls, independent typing.'
}finally{
 $app.Refresh();if(!$app.HasExited){
  Add-Type -AssemblyName System.Drawing;$rect=[MathomirUiProbe]::WindowRect($main);$image=New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top);$graphics=[System.Drawing.Graphics]::FromImage($image);$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$image.Size);$image.Save((Join-Path (Split-Path $exe) 'enlarged-overlap-ui.png'));$graphics.Dispose();$image.Dispose()
  Write-Output ('Last scene: '+$fixture+'; title='+[MathomirUiProbe]::Text($main)+'; view='+[MathomirUiProbe]::ClientRect($view).Right+','+[MathomirUiProbe]::ClientRect($view).Bottom)
  $app.Kill();$app.WaitForExit()
 }
}
