$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
  throw 'The IT Help Desk Cleaner companion can only be installed on Windows.'
}

$agentPath = Join-Path $PSScriptRoot 'AutoCleaningAgent.ps1'
if (-not (Test-Path -LiteralPath $agentPath -PathType Leaf)) {
  throw "Companion agent not found: $agentPath"
}

$powershellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powershellPath -PathType Leaf)) {
  throw 'Windows PowerShell was not found.'
}

$protocolKey = 'HKCU:\Software\Classes\ithelpdesk-cleaner'
$commandKey = Join-Path $protocolKey 'shell\open\command'
$command = '"{0}" -NoProfile -STA -WindowStyle Hidden -File "{1}" "%1"' -f $powershellPath, $agentPath

New-Item -Path $protocolKey -Force | Out-Null
Set-Item -Path $protocolKey -Value 'URL:IT Help Desk Cleaner'
New-ItemProperty -Path $protocolKey -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
New-Item -Path $commandKey -Force | Out-Null
Set-Item -Path $commandKey -Value $command

Write-Host 'IT Help Desk Cleaner is registered for this Windows user.'
Write-Host 'Restart your browser before testing the Auto Cleaning button.'
