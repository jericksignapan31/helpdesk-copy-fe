$ErrorActionPreference = 'Stop'
$protocolKey = 'HKCU:\Software\Classes\ithelpdesk-cleaner'

if (Test-Path -LiteralPath $protocolKey) {
  Remove-Item -LiteralPath $protocolKey -Recurse -Force
  Write-Host 'IT Help Desk Cleaner has been unregistered for this Windows user.'
} else {
  Write-Host 'IT Help Desk Cleaner was not registered for this Windows user.'
}
