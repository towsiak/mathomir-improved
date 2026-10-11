# Run the same overlap checks first, before the long general UI suite.
$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
$headerEnd=$all.IndexOf('$exe =')
if($headerEnd -lt 0){throw 'Could not locate shared UI probe definitions.'}
Invoke-Expression $all.Substring(0,$headerEnd)
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$appProcess=Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru
try{
  $main=[IntPtr]::Zero
  for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 250;$appProcess.Refresh();if($appProcess.HasExited){throw 'Application exited during overlap startup.'};if($appProcess.MainWindowHandle -ne 0){$main=$appProcess.MainWindowHandle;break}}
  if($main -eq [IntPtr]::Zero){throw 'No main window for overlap checks.'}
  $view=[MathomirUiProbe]::Child($main,0xE900)
  $start=$all.IndexOf('  # Interaction tests, not just static visibility:')
  $end=$all.IndexOf("  Write-Output 'Overlap interaction checks passed:",$start)
  if($start -lt 0 -or $end -lt 0){throw 'Could not locate shared overlap checks.'}
  $end=$all.IndexOf("`n",$end)
  Invoke-Expression $all.Substring($start,$end-$start)
}finally{
  if($main -ne [IntPtr]::Zero -and !$appProcess.HasExited){Add-Type -AssemblyName System.Drawing;$rect=[MathomirUiProbe]::WindowRect($main);$image=New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top);$graphics=[System.Drawing.Graphics]::FromImage($image);$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$image.Size);$image.Save((Join-Path (Split-Path $exe) 'overlap-ui.png'));$graphics.Dispose();$image.Dispose()}

  $trace=Join-Path (Split-Path $exe) 'overlap-diagnostics.txt'
  if(Test-Path $trace){Get-Content $trace -Tail 80|Write-Output}
  $appProcess.Refresh();if(!$appProcess.HasExited){Stop-Process -Id $appProcess.Id -Force}
}
