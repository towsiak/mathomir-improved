$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TablePreviewProbe {
 [DllImport("user32.dll",CharSet=CharSet.Ansi)] public static extern IntPtr GetProp(IntPtr h,string key);
 public static int Read(IntPtr h,string key){return GetProp(h,"TablePreview_"+key).ToInt32()-1;}
}
'@
function Check($ok,$why){if(!$ok){throw $why}}
function Capture($h,$path){
 $r=[MathomirUiProbe]::WindowRect($h)
 $image=New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top)
 $graphics=[Drawing.Graphics]::FromImage($image)
 try{$graphics.CopyFromScreen($r.Left,$r.Top,0,0,$image.Size);$image.Save($path)}finally{$graphics.Dispose();$image.Dispose()}
}
function Signature($h){
 Start-Sleep -Milliseconds 80
 $r=[MathomirUiProbe]::WindowRect($h)
 $image=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top)
 $graphics=[Drawing.Graphics]::FromImage($image)
 try{
  $graphics.CopyFromScreen($r.Left,$r.Top,0,0,$image.Size)
  $hash=[long]17;$ink=0
  for($y=3;$y -lt $image.Height-3;$y++) {for($x=3;$x -lt $image.Width-3;$x++){
   $color=$image.GetPixel($x,$y);$hash=($hash*31+$color.ToArgb())%1000000007
   if([Math]::Min($color.R,[Math]::Min($color.G,$color.B)) -lt 180){$ink++}
  }}
  return [pscustomobject]@{Hash=$hash;Ink=$ink}
 }finally{$graphics.Dispose();$image.Dispose()}
}
function SetValue($id,$value){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($script:dialog,$id),[string]$value)}
function Choose($id,$value){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($script:dialog,$id),334,$value)|Out-Null;[MathomirUiProbe]::Send($script:dialog,273,((1-shl 16)-bor $id))|Out-Null}
function Sample($checked){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($script:dialog,1128),241,[int]$checked)|Out-Null;[MathomirUiProbe]::Send($script:dialog,273,1128)|Out-Null}
function OpenTable {
 [MathomirUiProbe]::PostMessage($script:main,273,[IntPtr]33046,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 50;$i++){Start-Sleep -Milliseconds 100;$script:dialog=[MathomirUiProbe]::Window($script:app.Id,'Configure table');if($script:dialog -ne [IntPtr]::Zero){return}}
 throw 'Table dialog did not open.'
}
$exe=(Resolve-Path source/build/Mathomir.exe).Path
$folder=Split-Path $exe
$fixture=Join-Path $folder 'table-preview-native.mom'
'<?xml version="1.0"?><mathomir><o t="1" X="120" Y="120"><ex fh="100"><var t="q" f="00" /></ex></o></mathomir>'|Set-Content $fixture -Encoding ascii
$env:MATHOMIR_TABLE_DIAGNOSTICS='1';$env:MATHOMIR_DIAGNOSTIC_STARTUP='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$script:app=$app;$script:main=$app.MainWindowHandle
 Check ($main -ne [IntPtr]::Zero) 'App did not start.'
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;$baseline=(Get-Content $fixture -Raw)
 OpenTable;$preview=[MathomirUiProbe]::Child($dialog,1126)
 Check ($preview -ne [IntPtr]::Zero) 'Table layout preview missing from the same dialog.'
 $initial=Signature $preview;Check ($initial.Ink -gt 20) 'Default native table preview is blank.'
 SetValue 1121 3;$rows=Signature $preview;Check ($rows.Hash -ne $initial.Hash) 'Rows do not update preview.'
 SetValue 1122 5;$columns=Signature $preview;Check ($columns.Hash -ne $rows.Hash) 'Columns do not update preview.'
 SetValue 1123 40;$small=Signature $preview;SetValue 1123 200;$large=Signature $preview
 Check ($small.Hash -ne $large.Hash) 'Font changes do not update preview.'
 SetValue 1123 100
 $borderHashes=@();for($border=0;$border -lt 4;$border++){Choose 1124 $border;$borderHashes+=(Signature $preview).Hash}
 Check (($borderHashes|Sort-Object -Unique).Count -eq 4) 'Four border layouts are not visually distinct.'
 Choose 1124 0
 $alignHashes=@();for($align=0;$align -lt 3;$align++){Choose 1125 $align;$alignHashes+=(Signature $preview).Hash}
 Check (($alignHashes|Sort-Object -Unique).Count -eq 3) 'Left/center/right alignment is not visible with sample text.'
 Sample $false;$empty=Signature $preview;Sample $true;$filled=Signature $preview
 Check ($empty.Hash -ne $filled.Hash -and $filled.Ink -gt 0) 'Sample text toggle does not update preview.'
 foreach($case in @(@(0,5,100),@(1,1,100),@(21,5,100),@(3,13,100),@(3,5,39),@(3,5,801))){
  SetValue 1121 $case[0];SetValue 1122 $case[1];SetValue 1123 $case[2]
  Check (![MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($dialog,1))) 'Invalid table settings allow placement.'
 }
 SetValue 1121 20;SetValue 1122 12;SetValue 1123 800;$maximum=Signature $preview
 Check ([MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($dialog,1))) 'Maximum valid table rejected.'
 $r=[MathomirUiProbe]::WindowRect($preview)
 Check ([TablePreviewProbe]::Read($preview,'Width') -le $r.Right-$r.Left-10 -and [TablePreviewProbe]::Read($preview,'Height') -le $r.Bottom-$r.Top-10) 'Large table does not fit preview.'
 SetValue 1121 3;SetValue 1122 4;SetValue 1123 150;Choose 1124 2;Choose 1125 2
 Capture $dialog (Join-Path $folder 'table-dialog-preview.png')
 [MathomirUiProbe]::PostMessage($dialog,273,[IntPtr]2,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 150
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
 Check ((Get-Content $fixture -Raw) -eq $baseline) 'Preview or Cancel changed the document.'
 OpenTable;SetValue 1121 3;SetValue 1122 4;SetValue 1123 150;Choose 1124 1;Choose 1125 2
 [MathomirUiProbe]::PostMessage($dialog,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 200
 $view=[MathomirUiProbe]::Child($main,0xE900)
 [MathomirUiProbe]::Mouse($view,512,0,450,280);[MathomirUiProbe]::Mouse($view,513,1,450,280);[MathomirUiProbe]::Mouse($view,514,0,450,280)
 [MathomirUiProbe]::Send($view,256,27)|Out-Null;[MathomirUiProbe]::Send($view,258,27)|Out-Null
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
 [xml]$saved=Get-Content $fixture -Raw;$table=$saved.SelectSingleNode('/mathomir/*[last()]')
 Check ($saved.SelectNodes('/mathomir/*').Count -eq 2) 'Table was not placed independently.'
 Check ($table.SelectNodes('.//var | .//elm[@tp="1"]').Count -eq 0) 'Sample text leaked into placed table.'
 Check ($table.SelectNodes('.//col_sep').Count -eq 9 -and $table.SelectNodes('.//row_sep').Count -ge 2) 'Placed table has wrong row/column layout.'
 Write-Output 'Table dialog preview passed: native layout, all controls, four borders, three alignments, sample-only text, invalid states, maximum size, Cancel and empty native placement.'
}catch{
 if($dialog -ne [IntPtr]::Zero){Capture $dialog (Join-Path $folder 'table-dialog-failure.png')}
 throw
}finally{
 if(!$app.HasExited){Stop-Process -Id $app.Id -Force}
 Remove-Item Env:MATHOMIR_TABLE_DIAGNOSTICS -ErrorAction SilentlyContinue
}
