$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
function Check($ok,$why){if(!$ok){throw $why}}
function Capture($h,$name){
 $r=[MathomirUiProbe]::WindowRect($h);$image=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[Drawing.Graphics]::FromImage($image)
 try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$image.Size);$image.Save((Join-Path $folder $name))}finally{$g.Dispose();$image.Dispose()}
}
function SaveDoc {
 [MathomirUiProbe]::Mouse($view,512,0,700,430)
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
 return [xml](Get-Content $fixture -Raw)
}
function Target($doc){return $doc.SelectSingleNode('/mathomir/*[1]')}
function Background($doc){
 $object=Target $doc;$node=if($kind -in @('shape','group')){$object.SelectSingleNode('./appearance')}else{$object.SelectSingleNode('./ex | ./expr')}
 if($node -and $node.HasAttribute('bg')){return [int]$node.GetAttribute('bg')};return -1
}
function OpenPopup {
 Remove-Item (Join-Path $folder 'popup-colors-menu.txt') -ErrorAction SilentlyContinue
 $x=if($kind -in @('shape','group')){150}else{160};$y=if($kind -in @('shape','group')){155}else{175}
 [MathomirUiProbe]::Mouse($view,512,0,$x,$y);[MathomirUiProbe]::Mouse($view,516,2,$x,$y);[MathomirUiProbe]::Mouse($view,517,0,$x,$y)
 Start-Sleep -Milliseconds 100;$script:popup=[MathomirUiProbe]::Window($app.Id,'PopupMenu')
 Check ($popup -ne [IntPtr]::Zero) "No object popup for $kind"
 $script:options=@(Get-Content (Join-Path $folder 'popup-colors-menu.txt')|ForEach-Object{
  $parts=$_ -split ' ',5;[pscustomobject]@{Data=[int]$parts[0];X=[int]$parts[1];Y=[int]$parts[2];Enabled=[int]$parts[3]}
 })
 foreach($data in @(920,921,922,923,924,925,926,927,928,929)){Check (@($options|Where-Object Data -eq $data).Count -eq 1) "Missing background option $data for $kind"}
}
function Choose($data,[switch]$Async){
 $option=@($options|Where-Object Data -eq $data);Check ($option.Count -eq 1 -and $option[0].Enabled) "Missing/enabled color option $data for $kind"
 $option=$option[0]
 # Cross several other options before choosing: the action must keep its target.
 [MathomirUiProbe]::Mouse($popup,512,0,100,15);[MathomirUiProbe]::Mouse($popup,512,0,$option.X,$option.Y)
 if($Async){[MathomirUiProbe]::PostMessage($popup,513,[IntPtr]1,[IntPtr](($option.Y-shl 16)-bor $option.X))|Out-Null}
 else{[MathomirUiProbe]::Mouse($popup,513,1,$option.X,$option.Y)}
 Start-Sleep -Milliseconds 100
}
function ColorDialog {
 for($i=0;$i -lt 30;$i++){Start-Sleep -Milliseconds 100;$h=[MathomirUiProbe]::Dialog($app.Id);if($h -ne [IntPtr]::Zero){return $h}}
 throw 'Custom background color dialog did not open'
}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe
$env:MATHOMIR_POPUP_COLOR_DIAGNOSTICS='1';$env:MATHOMIR_DIAGNOSTIC_STARTUP='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start'
 $view=[MathomirUiProbe]::Child($main,0xE900)
 $presets=@(0xAAF8FF,0xFFEBD7,0xDAF8D7,0xE8DAFF,0xC3E3FF,0xFFDCEB,0xE4E4E4,0xFFFFFF)
 $inks=@(0,0xCC,0xCC00,0xC00000,0x909090,0x80D0,0xA03080,0x808000)
 $line='<dw d="32|0,0;3840,0;3840,2560;0,2560;0,0" />'
 $neighbor='<o t="1" X="500" Y="180"><ex fh="160"><var t="neighbor" f="00" /></ex></o>'
 foreach($kind in @('text','math','shape','group')){
  $body=switch($kind){
   text {'<o t="1" X="150" Y="180"><ex fh="160" stxt="1"><var t="displacement" f="00" /></ex></o>'}
   math {'<o t="1" X="150" Y="180"><ex fh="160"><var t="x" f="00" /><opr s="=" /><var t="2" f="00" /></ex></o>'}
   shape {'<o t="2" X="150" Y="130">'+$line+'</o>'}
   group {'<o t="2" X="150" Y="130"><gr d="0,0;3840,2560">'+$line+'</gr></o>'}
  }
  $script:fixture=Join-Path $folder ("object-colors-$kind.mom");('<?xml version="1.0"?><mathomir>'+$body+$neighbor+'</mathomir>')|Set-Content $fixture -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200
  [MathomirUiProbe]::Send($view,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
  $baseline=SaveDoc;$neighborXml=$baseline.mathomir.ChildNodes[1].OuterXml
  $base=if($kind -in @('shape','group')){580}else{80}
  for($ink=0;$ink -lt 8;$ink++){
   OpenPopup;Choose ($base+$ink+1);$saved=SaveDoc
   Check ($saved.mathomir.ChildNodes[1].OuterXml -eq $neighborXml) "Foreground changed neighbor for $kind"
   if($kind -in @('shape','group')){
    Check ([MathomirUiProbe]::CountColor($view,149,145,4,30,$inks[$ink]) -gt 5) "Drawing foreground $ink not painted for $kind"
   }else{Check ((Target $saved).SelectNodes('.//*[@color="'+$ink+'"] | self::*[@color="'+$ink+'"]').Count -gt 0) "Typed foreground $ink not persisted for $kind"}
  }
  for($i=0;$i -lt 8;$i++){
   OpenPopup;if($i -eq 0){Capture $popup ("object-colors-$kind-popup.png")};Choose (920+$i);$saved=SaveDoc
   Check ((Background $saved) -eq $presets[$i]) "Background $i not persisted for $kind"
   Check ($saved.mathomir.ChildNodes[1].OuterXml -eq $neighborXml) "Background changed neighbor for $kind"
   if($kind -in @('shape','group')){Check ([MathomirUiProbe]::CountColor($view,170,145,30,30,$presets[$i]) -gt 850) "Drawing background $i not painted for $kind"}
  }
  $before=$saved.OuterXml
  OpenPopup;Choose 928 -Async;$dialog=ColorDialog
  [MathomirUiProbe]::PostMessage($dialog,273,[IntPtr]2,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 150
  Check ((SaveDoc).OuterXml -eq $before) "Custom Cancel changed $kind"
  OpenPopup;Choose 928 -Async;$dialog=ColorDialog
  foreach($pair in @(@(706,37),@(707,99),@(708,181))){$edit=[MathomirUiProbe]::Child($dialog,$pair[0]);Check ($edit -ne [IntPtr]::Zero) 'Native RGB control missing';[MathomirUiProbe]::SetText($edit,[string]$pair[1])}
  [MathomirUiProbe]::PostMessage($dialog,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 200
  $custom=37+99*256+181*65536;$saved=SaveDoc;Check ((Background $saved) -eq $custom) "Custom RGB not saved for $kind"
  [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200;Check ((Background (SaveDoc)) -eq $custom) "Reopen lost $kind background"
  OpenPopup;Choose 929;$cleared=SaveDoc;Check ((Background $cleared) -eq -1) "Clear failed for $kind"
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$restored=SaveDoc;Check ((Background $restored) -eq $custom) "Undo did not restore $kind background"
  Check ($restored.mathomir.ChildNodes[1].OuterXml -eq $neighborXml) "Undo changed neighbor for $kind"
  Capture $view ("object-colors-$kind-result.png")
  Write-Output "Object appearance passed: $kind, eight inks, eight backgrounds, custom/cancel, clear, Undo, save/reopen, neighbor isolation"
 }
 # A mixed text/drawing selection should receive one background action and one Undo.
 foreach($reverse in @($false,$true)){
  $kind='shape';$fixture=Join-Path $folder ("object-colors-mixed-$reverse.mom")
  $shape='<o t="2" X="150" Y="130">'+$line+'</o>'
  $objects=if($reverse){$neighbor+$shape}else{$shape+$neighbor}
  ('<?xml version="1.0"?><mathomir>'+$objects+'</mathomir>')|Set-Content $fixture -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200;$before=(SaveDoc).OuterXml
  [MathomirUiProbe]::Send($view,273,0xE12A)|Out-Null;OpenPopup;Choose 923;$mixed=SaveDoc
  Check ($mixed.SelectNodes('/mathomir/*/appearance[@bg="15260415"] | /mathomir/*/*[self::ex or self::expr][@bg="15260415"]').Count -eq 2) 'Mixed selection background did not reach text and drawing'
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;Check ((SaveDoc).OuterXml -eq $before) 'Mixed selection background did not Undo in one step'
 }
 Write-Output 'Object appearance checks passed for shared text/math/drawing/group menus and mixed selection.'
}catch{
 $failure=$_
 try{if($main -ne [IntPtr]::Zero){Capture $main 'object-colors-failure.png'}}catch{Write-Output 'Application window unavailable for failure screenshot.'}
 throw $failure
}finally{
 if(!$app.HasExited){Stop-Process -Id $app.Id -Force}
 Remove-Item Env:MATHOMIR_POPUP_COLOR_DIAGNOSTICS -ErrorAction SilentlyContinue
}
