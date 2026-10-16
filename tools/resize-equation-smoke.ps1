$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'large-resize-grip-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe='))
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$folder=Split-Path $exe
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $script:fixture -Raw)}
function Font($doc){$e=$doc.SelectSingleNode('/mathomir/*[1]/*[self::ex or self::expr]');if($e.HasAttribute('fh')){return [int]$e.fh};return [int]$e.fnt_h}
function HoverObject {$r=[MathomirUiProbe]::ClientRect($view);$p=[LargeGripProbe]::FindInk($view,$r.Right,$r.Bottom);[MathomirUiProbe]::Mouse($view,512,0,$p[0],$p[1]);Start-Sleep -Milliseconds 80}
function Grip {$r=[MathomirUiProbe]::ClientRect($view);return [LargeGripProbe]::Find($view,$r.Right,$r.Bottom)}
function Drag($g,$dx,$dy,$release=$true){
 [MathomirUiProbe]::Mouse($view,512,0,$g[0],$g[1]);[MathomirUiProbe]::Mouse($view,513,1,$g[0],$g[1]);
 for($i=1;$i -le 12;$i++){[MathomirUiProbe]::Mouse($view,512,1,($g[0]+[int]($dx*$i/12)),($g[1]+[int]($dy*$i/12)));Start-Sleep -Milliseconds 25}
 if($release){[MathomirUiProbe]::Mouse($view,514,0,($g[0]+$dx),($g[1]+$dy))}
}
function Shape($doc){$copy=$doc.Clone();foreach($e in $copy.SelectNodes('//ex | //expr')){$e.RemoveAttribute('fh');$e.RemoveAttribute('fnt_h')};$copy.mathomir.FirstChild.RemoveAttribute('X');$copy.mathomir.FirstChild.RemoveAttribute('Y');return $copy.OuterXml}
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,0xE900)
 $radical='<elm tp="8" E1=""><ex fh="90"><var t="x" f="00" /></ex></elm>'
 $power='<elm tp="3" E1="" E2=""><ex fh="100"><var t="x" f="00" /></ex><ex fh="70"><fra E1="n" E2="d"><ex fh="63"><var t="1" f="00" /></ex><ex fh="63"><var t="2" f="00" /></ex></fra></ex></elm>'
 $left='<elm tp="5" E1=""><ex fh="100" br="1" shp="("><var t="2" f="00" />'+$radical+'</ex></elm><opr s="\27" />'
 $right='<elm tp="5" E1=""><ex fh="100" br="1" shp="("><var t="2" f="00" />'+$power+'</ex></elm><opr s="\27" />'
 $cases=@(
  @{name='equals';body='<opr s="=" />'},
  @{name='simple';body='<var t="x" f="00" /><opr s="=" /><var t="2" f="00" />'},
  @{name='radical-power-primes';body=$left+'<opr s="=" />'+$right},
  @{name='equals-label';body='<var t="x" f="00" /><opr s="=" E1="upp"><ex fh="70"><var t="rule" f="00" /></ex></opr>'+ $radical}
 )
 foreach($case in $cases){foreach($font in @(100,600,1200)){foreach($zoom in @(60,100,200)){
  Write-Output ('Starting resize: '+$case.name+' font='+$font+' zoom='+$zoom)
  $script:fixture=Join-Path $folder ('resize-equation-'+$case.name+'-'+$font+'-'+$zoom+'.mom')
  $body=$case.body
  # Scale all authored child fonts together, retaining radical/power proportions.
  $body=[regex]::Replace($body,'fh="(\d+)"',{param($m)'fh="'+[int]([int]$m.Groups[1].Value*$font/100)+'"'})
  ('<?xml version="1.0"?><mathomir><o t="1" X="40" Y="180"><ex fh="'+$font+'">'+$body+'</ex></o></mathomir>')|Set-Content $fixture -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 150
  [MathomirUiProbe]::Send($view,273,$(if($zoom -eq 60){32777}elseif($zoom -eq 200){33019}else{32775}))|Out-Null
  [MathomirUiProbe]::Send($view,276,4)|Out-Null;for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
  HoverObject;$before=SaveDoc;$original=Shape $before;$initialFont=Font $before
  $g=Grip;Drag $g 90 55;$grown=SaveDoc
  if((Font $grown) -le $initialFont){throw 'Equation did not enlarge'}
  if((Shape $grown) -ne $original){throw 'Resizing changed mathematical contents'}
  HoverObject;$g=Grip;Drag $g -45 -30;$shrunk=SaveDoc
  if((Font $shrunk) -ge (Font $grown)){throw 'Equation did not shrink'}
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$restored=SaveDoc
  if((Font $restored) -ne (Font $grown)){throw 'Undo did not restore enlarged equation'}
  HoverObject;$g=Grip;Drag $g 60 35 $false;[MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null;$cancelled=SaveDoc
  if((Font $cancelled) -ne (Font $grown)){throw 'Escape did not restore font'}
  if((Shape $cancelled) -ne $original){throw 'Undo or Escape altered equation contents'}
  Write-Output ('Passed resize: '+$case.name+' font='+$font+' zoom='+$zoom)
 }}}
 Write-Output 'Equation resizing passed: equals, equations, roots/powers/primes, operator labels; 36 cases; grow/shrink/Undo/Escape/content preservation.'
}finally{if(!$app.HasExited){$app.Kill();$app.WaitForExit()}}
