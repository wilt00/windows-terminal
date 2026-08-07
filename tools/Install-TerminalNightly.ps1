#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSEdition -ne 'Desktop')
{
    throw 'Run this installer with Windows PowerShell (powershell.exe), not pwsh.'
}

$releaseDirectory = $PSScriptRoot
$certificateFile = Get-ChildItem $releaseDirectory -Filter 'WindowsTerminalPersonal.cer' -File | Select-Object -First 1
$bundleFile = Get-ChildItem $releaseDirectory -Filter 'WindowsTerminalPersonal_*.msixbundle' -File | Select-Object -First 1

if (-not $certificateFile -or -not $bundleFile)
{
    throw 'Place this script, WindowsTerminalPersonal.cer, and the .msixbundle in the same directory.'
}

$certificatePath = $certificateFile.FullName
$bundlePath = $bundleFile.FullName

$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
$trustedCertificate = Get-ChildItem "Cert:\CurrentUser\TrustedPeople\$($certificate.Thumbprint)" -ErrorAction SilentlyContinue
if (-not $trustedCertificate)
{
    Write-Host "Trusting nightly signing certificate CN=wilt00 ($($certificate.Thumbprint))..." -ForegroundColor Yellow
    Import-Certificate -FilePath $certificatePath -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
}

Get-ChildItem $releaseDirectory -Filter 'Microsoft.UI.Xaml*.appx' -File | ForEach-Object {
    Write-Host "Installing dependency $($_.Name)..." -ForegroundColor Cyan
    Add-AppxPackage -Path $_.FullName -ErrorAction SilentlyContinue
}

Write-Host "Installing $([IO.Path]::GetFileName($bundlePath))..." -ForegroundColor Cyan
Add-AppxPackage -Path $bundlePath -ForceApplicationShutdown -ForceUpdateFromAnyVersion
Write-Host 'Windows Terminal Personal installed. Launch it from Start or run: wtd' -ForegroundColor Green
