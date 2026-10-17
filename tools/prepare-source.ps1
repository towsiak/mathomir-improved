$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    if(Test-Path source){throw 'Source already exists. Prepare a fresh checkout instead of reapplying overlays.'}
    git clone https://github.com/mathomir/Mathomir_GIT.git source
    if($LASTEXITCODE -ne 0){throw 'Upstream clone failed.'}
    git -C source checkout 0300c13e5108fb6112403b20f576d977db3309f9
    if($LASTEXITCODE -ne 0){throw 'Pinned upstream checkout failed.'}
    $patches=@(Get-Content source-patches.txt | Where-Object { $_.Trim() -and !$_.Trim().StartsWith('#') })
    if(($patches | Sort-Object -Unique).Count -ne $patches.Count){throw 'Patch manifest contains duplicate entries.'}
    foreach($patch in $patches){
        if(!(Test-Path -LiteralPath $patch -PathType Leaf)){throw ('Missing source patch: '+$patch)}
        git -C source apply --ignore-space-change ('../'+$patch)
        if($LASTEXITCODE -ne 0){throw ('Source patch failed: '+$patch)}
    }
    Copy-Item Mathomir.vcxproj source/Mathomir/
    ./tools/setup-math-renderer.ps1
} finally {
    Pop-Location
}
