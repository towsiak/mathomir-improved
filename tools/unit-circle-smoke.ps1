# Verify the actual native dialog, placement, signed labels, saved arc and arrow.
$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
$headerEnd=$all.IndexOf('$exe =')
if($headerEnd -lt 0){throw 'Could not locate shared UI probe definitions.'}
Invoke-Expression $all.Substring(0,$headerEnd)
function Read-UnitLine($node){
  $points=@()
  if($node.HasAttribute('d')){
    $data=$node.GetAttribute('d').Split('|');$width=[int]$data[0];$x=0.;$y=0.
    foreach($pair in $data[1].Split(';')){
      $xy=$pair.Split(',');if($xy[0] -ne ':'){$x=[double]$xy[0]};if($xy[1] -ne ':'){$y=[double]$xy[1]}
      $points+=@{x=$x/32.;y=$y/32.}
    }
  }else{
    $width=[int]$node.GetAttribute('width')*32/1000
    for($i=1;$node.HasAttribute('X'+$i);$i++){$points+=@{x=[double]$node.GetAttribute('X'+$i)/1000.;y=[double]$node.GetAttribute('Y'+$i)/1000.}}
  }
  return @{width=$width;points=$points}
}
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$appProcess=Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru
try{
  $main=[IntPtr]::Zero
  for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 250;$appProcess.Refresh();if($appProcess.HasExited){throw 'Application exited during unit-circle startup.'};if($appProcess.MainWindowHandle -ne 0){$main=$appProcess.MainWindowHandle;break}}
  if($main -eq [IntPtr]::Zero){throw 'No main window for unit-circle checks.'}
  $view=[MathomirUiProbe]::Child($main,0xE900)
  $cases=@(
    @{a='0';b='-90';start=0.;end=-90.;sweep=-90.;mode=0;direction=0;negative=$true},
    @{a='0';b='90';start=0.;end=90.;sweep=90.;mode=0;direction=0;negative=$false},
    @{a='0';b='-270';start=0.;end=-270.;sweep=-270.;mode=0;direction=0;negative=$true},
    @{a='90';b='-90';start=90.;end=-90.;sweep=-180.;mode=0;direction=0;negative=$true},
    @{a='0';b='-pi/2';start=0.;end=-90.;sweep=-90.;mode=1;direction=0;negative=$true},
    @{a='0';b='-1.234';start=0.;end=(-1.234*180/[Math]::PI);sweep=(-1.234*180/[Math]::PI);mode=1;direction=0;negative=$true},
    @{a='0';b='-360';start=0.;end=-360.;sweep=-360.;mode=0;direction=0;negative=$true},
    @{a='0';b='-720';start=0.;end=-720.;sweep=-720.;mode=0;direction=0;negative=$true},
    @{a='350';b='370';start=350.;end=370.;sweep=20.;mode=0;direction=0;negative=$false},
    @{a='0';b='0';start=0.;end=0.;sweep=0.;mode=0;direction=0;negative=$false},
    @{a='0';b='-90';start=0.;end=-90.;sweep=270.;mode=0;direction=1;negative=$true},
    @{a='0';b='90';start=0.;end=90.;sweep=-270.;mode=0;direction=2;negative=$false}
  )
  $index=0
  foreach($case in $cases){
    $fixture=Join-Path (Split-Path $exe) ('signed-unit-circle-'+$index+'.mom');$index++
    '<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $fixture -Encoding ascii
    [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250
    [MathomirUiProbe]::Send($view,273,32775)|Out-Null
    [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33052,[IntPtr]::Zero)|Out-Null
    $dialog=[IntPtr]::Zero
    for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 100;$dialog=[MathomirUiProbe]::Window($appProcess.Id,'Unit circle maker');if($dialog -ne [IntPtr]::Zero){break}}
    if($dialog -eq [IntPtr]::Zero){throw 'Unit-circle dialog did not open.'}
    if([MathomirUiProbe]::Send([MathomirUiProbe]::Child($dialog,1134),327,0) -ne 0){throw 'Signed automatic direction was not the default.'}
    [MathomirUiProbe]::Send([MathomirUiProbe]::Child($dialog,1133),334,$case.mode)|Out-Null
    [MathomirUiProbe]::Send([MathomirUiProbe]::Child($dialog,1134),334,$case.direction)|Out-Null
    [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($dialog,1130),$case.a)
    [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($dialog,1131),$case.b)
    foreach($id in @(1136,1138,1139)){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($dialog,$id),241,0)|Out-Null}
    [MathomirUiProbe]::PostMessage($dialog,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null
    for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 100;if(![MathomirUiProbe]::IsWindowVisible($dialog)){break}}
    if([MathomirUiProbe]::IsWindowVisible($dialog)){throw 'Signed unit-circle inputs were rejected.'}
    [MathomirUiProbe]::Mouse($view,512,0,150,150);[MathomirUiProbe]::Mouse($view,513,1,150,150);[MathomirUiProbe]::Mouse($view,514,0,150,150)
    [MathomirUiProbe]::Send($view,258,27)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
    [xml]$saved=Get-Content $fixture -Raw
    $object=$saved.SelectSingleNode('/mathomir/*[last()]')
    $labels=$object.SelectNodes('.//subexp/*[self::ex or self::expr]')
    $expectedLabels=if($case.start -eq $case.end){1}else{2}
    if($labels.Count -ne $expectedLabels){throw "Missing endpoint labels: $($case.a) to $($case.b)"}
    $negative=$null -ne $labels[-1].SelectSingleNode('./opr[@s="-"] | ./elm[@tp="2"][@stp="-"]')
    if($negative -ne $case.negative){throw "Wrong endpoint sign: $($case.b)"}
    $lines=@($object.SelectNodes('.//dw | .//draw')|ForEach-Object {Read-UnitLine $_})
    $arc=@($lines|Where-Object {$_.width -eq 96})
    $arrow=@($lines|Where-Object {$_.width -eq 64})
    $segments=0;foreach($line in $arc){$segments+=$line.points.Count-1}
    if($segments -ne [int][Math]::Ceiling([Math]::Abs($case.sweep)/2.)){throw "Wrong arc extent: $($case.a) to $($case.b), $segments segments"}
    if($segments -eq 0){if($arrow.Count -ne 1){throw 'Zero rotation drew an arrow.'};continue}
    $first=$arc[0].points[0];$r=105.;$a=$case.start*[Math]::PI/180.
    $cx=$first.x-$r*[Math]::Cos($a);$cy=$first.y+$r*[Math]::Sin($a);$total=0.
    foreach($line in $arc){
      for($i=1;$i -lt $line.points.Count;$i++){
        $p=$line.points[$i-1];$q=$line.points[$i]
        $a=[Math]::Atan2($cy-$p.y,$p.x-$cx);$b=[Math]::Atan2($cy-$q.y,$q.x-$cx);$delta=$b-$a
        if($delta -gt [Math]::PI){$delta-=2*[Math]::PI};if($delta -lt -[Math]::PI){$delta+=2*[Math]::PI}
        if($delta*$case.sweep -le 0){throw 'Arc travelled in the wrong direction.'};$total+=$delta*180/[Math]::PI
        if($case.start -eq 0 -and $case.end -eq -90 -and $case.direction -eq 0){if($q.x -lt $cx-.1 -or $q.y -lt $cy-.1){throw 'Negative quarter-turn escaped the fourth quadrant.'}}
      }
    }
    if([Math]::Abs($total-$case.sweep) -gt .1){throw "Arc angular sweep was $total, expected $($case.sweep)."}
    $tip=$arc[-1].points[-1];$angle=$case.end*[Math]::PI/180.;$sign=if($case.sweep -lt 0){-1.}else{1.}
    $tx=-[Math]::Sin($angle)*$sign;$ty=-[Math]::Cos($angle)*$sign
    foreach($line in $arrow[0..1]){
      $p=$line.points[0];$q=$line.points[1]
      if([Math]::Abs($p.x-$tip.x) -gt .1 -or [Math]::Abs($p.y-$tip.y) -gt .1){throw 'Arrowhead missed the arc endpoint.'}
      if([Math]::Abs(($p.x-$q.x)*$tx+($p.y-$q.y)*$ty-10) -gt .1){throw 'Arrowhead pointed against the signed tangent.'}
    }
    [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200
    [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
    [xml]$reopened=Get-Content $fixture -Raw
    if($reopened.SelectNodes('//subexp/*[self::ex or self::expr]').Count -ne $expectedLabels){throw 'Unit-circle labels did not survive reopening.'}
  }
  Write-Output 'Signed unit-circle UI passed: negative degrees/radians, exact pi and decimal labels, default quarter-turn, measured signed arc, tangent arrowheads, full turns, zero sweep, direction overrides and reopen.'
}finally{$appProcess.Refresh();if(!$appProcess.HasExited){Stop-Process -Id $appProcess.Id -Force}}
