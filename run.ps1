# win-11 : lanceur distant (irm https://is.gd/win11install | iex)
# Telecharge le depot complet (moteur + interface graphique) et lance le menu en administrateur.
$zip = "$env:TEMP\win-11.zip"
$dir = "$env:TEMP\win-11"
Invoke-WebRequest 'https://github.com/matglitch-974/win-11/archive/refs/heads/master.zip' -OutFile $zip -UseBasicParsing
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive $zip $dir -Force
$engine = Get-ChildItem $dir -Recurse -Filter win11.ps1 | Select-Object -First 1 -ExpandProperty FullName
Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$engine`""
