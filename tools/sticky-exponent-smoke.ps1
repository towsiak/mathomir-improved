$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$appProcess=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function TypeMath([string]$text){foreach($character in $text.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$character)|Out-Null}}
function SavedRoot {
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
 $doc=[xml](Get-Content $file -Raw)
 return $doc.SelectSingleNode('/mathomir/*[last()]/*[self::ex or self::expr]')
}
function Variables($node){return (($node.SelectNodes('.//var | .//elm[@tp="1"]')|ForEach-Object{if($_.HasAttribute('t')){$_.t}else{$_.tx}}) -join '')}
function AssertExponent($root,[string]$expected){
 Check ($null -ne $root) 'No typed equation was saved'
 $power=$root.SelectSingleNode('./elm[@tp="3"]')
 Check ($null -ne $power) ('Power left the baseline: '+$root.OuterXml)
 $children=$power.SelectNodes('./ex | ./expr')
 Check ($children.Count -eq 2) ('Power lost its base or exponent: '+$root.OuterXml)
 Check ((Variables $children[0]) -eq 'x') ('Base changed during exponent typing: '+$root.OuterXml)
 Check ((Variables $children[1]) -eq $expected) ('Characters escaped the exponent: '+$root.OuterXml)
 Check ($null -eq $root.SelectSingleNode('./opr | ./elm[@tp="2"]')) ('Operator escaped the exponent: '+$root.OuterXml)
 Check ((Variables $root) -eq ('x'+$expected)) ('Unexpected baseline text: '+$root.OuterXml)
 return $children[1]
}
try {
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 200;$appProcess.Refresh();if($appProcess.MainWindowHandle -ne 0){break}}
 $main=$appProcess.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,59648)
 Check ($view -ne [IntPtr]::Zero) 'No native editing view'
 $cases=@(
  @{start='x^1';suffix='/2';expected='12';op='/'},
  @{start='x^1';suffix='+2';expected='12';op='+'},
  @{start='x^1';suffix='-2';expected='12';op='-'},
  @{start='x^1';suffix='*2';expected='12';op=$null},
  @{start='x^n';suffix='+1';expected='n1';op='+'},
  @{start='x^12';suffix='/3';expected='123';op='/'},
  @{start='x^1';suffix='/2+3/4';expected='1234';op='/'}
 )
 $n=0
 foreach($case in $cases){
  $n++;$file=Join-Path (Split-Path $exe) ('sticky-exponent-'+$n+'.mom')
  '<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $file -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400
  [MathomirUiProbe]::Send($main,273,32775)|Out-Null
  [MathomirUiProbe]::Mouse($view,512,0,250,180);[MathomirUiProbe]::Mouse($view,513,1,250,180);[MathomirUiProbe]::Mouse($view,514,0,250,180)
  TypeMath $case.start
  if($n -eq 1){
   # A pause, redraw and hover must not take typing back to the baseline.
   $null=AssertExponent (SavedRoot) '1'
   [MathomirUiProbe]::Mouse($view,512,0,450,250);Start-Sleep -Milliseconds 1200
  }
  TypeMath $case.suffix
  $root=SavedRoot;$exponent=AssertExponent $root $case.expected
  Check ($null -ne $exponent.SelectSingleNode('.//opr | .//elm[@tp="2"]')) ('Exponent lost its arithmetic operator: '+$root.OuterXml)
  if($case.op){
   Check ($null -ne $exponent.SelectSingleNode(('.//opr[@s="{0}"] | .//elm[@tp="2"][@stp="{0}"]' -f $case.op))) ('Exponent lost '+$case.op+': '+$root.OuterXml)
  }
  $before=$exponent.OuterXml
  TypeMath "`r+7"
  $root=SavedRoot;$after=$root.SelectSingleNode('./elm[@tp="3"]/*[self::ex or self::expr][2]')
  Check ($after.OuterXml -eq $before) ('Enter did not leave the exponent: '+$root.OuterXml)
  Check ($null -ne $root.SelectSingleNode('./opr[@s="+"] | ./elm[@tp="2"][@stp="+"]')) ('Enter did not resume baseline operators: '+$root.OuterXml)
  Check ((Variables $root) -eq ('x'+$case.expected+'7')) ('Baseline input was lost after Enter: '+$root.OuterXml)
  [MathomirUiProbe]::Send($view,258,27)|Out-Null
  Write-Output ('Exponent typing passed: '+$case.start+$case.suffix+', stays upstairs through operators and leaves with Enter.')
 }
 $file=Join-Path (Split-Path $exe) 'sticky-exponent-arrow.mom'
 '<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $file -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400
 [MathomirUiProbe]::Mouse($view,512,0,250,180);[MathomirUiProbe]::Mouse($view,513,1,250,180);[MathomirUiProbe]::Mouse($view,514,0,250,180)
 TypeMath 'x^2';$null=AssertExponent (SavedRoot) '2'
 [MathomirUiProbe]::Send($view,256,39)|Out-Null;TypeMath '+7'
 $root=SavedRoot
 Check ((Variables $root.SelectSingleNode('./elm[@tp="3"]/*[self::ex or self::expr][2]')) -eq '2') ('Right arrow did not leave the exponent: '+$root.OuterXml)
 Check ($null -ne $root.SelectSingleNode('./opr[@s="+"] | ./elm[@tp="2"][@stp="+"]')) ('Right arrow did not resume baseline operators: '+$root.OuterXml)
 Write-Output 'Explicit right-arrow exit passed: x^2, Right, +7.'
}catch{
 Write-Output ('Exponent test process exited: '+$appProcess.HasExited)
 if(Test-Path $file){Get-Content $file|Write-Output}
 Get-ChildItem (Split-Path $exe) -Filter 'asan*' -File|ForEach-Object{Get-Content $_.FullName|Write-Output}
 throw
}finally{if(!$appProcess.HasExited){$appProcess.Kill();$appProcess.WaitForExit()}}
