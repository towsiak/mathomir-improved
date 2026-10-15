$ErrorActionPreference='Stop'
function Pinned($url,$path,$sha){
 if(!(Test-Path $path) -or (Get-FileHash $path -Algorithm SHA256).Hash -ne $sha){Invoke-WebRequest $url -OutFile $path}
 if((Get-FileHash $path -Algorithm SHA256).Hash -ne $sha){throw ('Download integrity check failed: '+$path)}
}
$sdk=Join-Path $PSScriptRoot '.webview2'
New-Item -ItemType Directory -Force $sdk,source/build/MathomirMath | Out-Null
$package=Join-Path $sdk 'sdk.zip'
Pinned 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.2903.40/microsoft.web.webview2.1.0.2903.40.nupkg' $package 'ef128016dd1e51c59178c827ed5b8aa3322c57afa8675d930f8109505542ad74'
Expand-Archive $package $sdk -Force
Copy-Item MathomirMath/* source/build/MathomirMath/
Pinned 'https://raw.githubusercontent.com/mathjax/MathJax/3.2.2/es5/tex-svg.js' 'source/build/MathomirMath/tex-svg.js' 'd4295dc33744836935c1399feece5159577b34c5c8ffb9f1c6324cd82e03a882'
New-Item -ItemType Directory -Force source/build/MathomirMath/ui | Out-Null
Pinned 'https://raw.githubusercontent.com/mathjax/MathJax/3.2.2/es5/ui/safe.js' 'source/build/MathomirMath/ui/safe.js' '9fef48d868277a8bc1852f7ba796b33ead812d38916a7131b0a29ea48961a6a4'
Pinned 'https://raw.githubusercontent.com/mathjax/MathJax/3.2.2/LICENSE' 'source/build/MathomirMath/MathJax-LICENSE.txt' 'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30'
New-Item -ItemType Directory -Force source/build/MathomirMath/input/tex/extensions | Out-Null
Pinned 'https://raw.githubusercontent.com/mathjax/MathJax/3.2.2/es5/input/tex/extensions/boldsymbol.js' 'source/build/MathomirMath/input/tex/extensions/boldsymbol.js' 'd6771fee0772db2657796c8d0e20e1878bb3237f6d3ed1e828e1834a4ff743ca'
