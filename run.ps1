# win-11 : lanceur distant (irm https://is.gd/win11install | iex)
# Telecharge le moteur win11.ps1 et l'execute en administrateur.
$url = 'https://raw.githubusercontent.com/matglitch-974/win-11/master/win11.ps1'
$dst = "$env:TEMP\win11.ps1"
Invoke-WebRequest $url -OutFile $dst -UseBasicParsing
Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$dst`""
