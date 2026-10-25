function Wait-MathomirPopupOptions([string]$path,[int[]]$required){
 for($wait=0;$wait -lt 50;$wait++){
  $items=@()
  if(Test-Path $path){
   foreach($line in Get-Content $path -ErrorAction SilentlyContinue){
    $p=$line -split ' ',5;$data=0;$x=0;$y=0;$enabled=0
    if($p.Count -ge 4 -and [int]::TryParse($p[0],[ref]$data) -and [int]::TryParse($p[1],[ref]$x) -and [int]::TryParse($p[2],[ref]$y) -and [int]::TryParse($p[3],[ref]$enabled)){
     $items+=[pscustomobject]@{Data=$data;X=$x;Y=$y;Enabled=$enabled}
    }
   }
  }
  $ready=$true
  foreach($id in $required){if(@($items|Where-Object Data -eq $id).Count -ne 1){$ready=$false;break}}
  if($ready){return $items}
  Start-Sleep -Milliseconds 25
 }
 throw ('Native popup options missing after paint: '+($required -join ', '))
}
