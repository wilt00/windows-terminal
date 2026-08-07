#Requires -Version 7

[CmdletBinding()]
param(
    [ValidateRange(1, 64)]
    [int]$MaxCpuCount = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CheckedNative
{
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0)
    {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($ArgumentList -join ' ')"
    }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $root 'OpenConsole.slnx'
$nuget = Join-Path $root 'dep\nuget\nuget.exe'
$packageDirectory = Join-Path $root 'src\cascadia\CascadiaPackage'
$recipe = Join-Path $packageDirectory 'bin\x64\Release\CascadiaPackage.build.appxrecipe'

Push-Location $root
try
{
    Write-Host 'Switching to personal and pulling me/personal...' -ForegroundColor Cyan
    Invoke-CheckedNative git @('switch', 'personal')
    Invoke-CheckedNative git @('pull', '--ff-only', 'me', 'personal')

    $localChanges = @(git status --porcelain)
    if ($LASTEXITCODE -ne 0)
    {
        throw 'Unable to read the Git working-tree status.'
    }
    if ($localChanges.Count -gt 0)
    {
        Write-Warning 'The working tree contains local changes. They will be included in the build.'
    }

    Write-Host 'Restoring NuGet packages...' -ForegroundColor Cyan
    Invoke-CheckedNative $nuget @('restore', $solution, '-Verbosity', 'quiet')
    Invoke-CheckedNative $nuget @('restore', (Join-Path $root 'dep\nuget\packages.config'), '-Verbosity', 'quiet')

    $vswhereCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe')
        Get-ChildItem (Join-Path $root 'packages') -Filter vswhere.exe -Recurse -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    ) | Where-Object { $_ -and (Test-Path $_) }

    $vswhere = $vswhereCandidates | Select-Object -First 1
    if (-not $vswhere)
    {
        throw 'Could not find vswhere.exe. Install Visual Studio or run tools\razzle.cmd once.'
    }

    $vswhereArguments = @(
        '-latest',
        '-prerelease',
        '-products', '*',
        '-requires', 'Microsoft.Component.MSBuild',
        '-version', '[17.0,19.0)'
    )

    $installationPath = (& $vswhere @vswhereArguments '-property' 'installationPath' | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $installationPath)
    {
        throw 'Could not locate a compatible Visual Studio installation.'
    }

    # Use 64-bit MSBuild for the x64 build. The Terminal projects intentionally
    # no longer override PreferredToolArchitecture, so using 32-bit MSBuild can
    # make LIB default to /MACHINE:X86 for static WinRT libraries.
    $msbuild = (& $vswhere @vswhereArguments '-find' 'MSBuild\**\Bin\amd64\MSBuild.exe' | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $msbuild -or -not (Test-Path $msbuild))
    {
        throw 'Could not locate 64-bit MSBuild.exe.'
    }

    Write-Host "Rebuilding Terminal Dev (Release|x64, $MaxCpuCount concurrent jobs)..." -ForegroundColor Cyan
    Invoke-CheckedNative $msbuild @(
        $solution,
        '/t:Terminal\CascadiaPackage:Rebuild',
        '/p:Configuration=Release',
        '/p:Platform=x64',
        '/p:GenerateAppxPackageOnBuild=false',
        '/p:AppxSymbolPackageEnabled=false',
        "/p:CL_MPCount=$MaxCpuCount",
        "/m:$MaxCpuCount",
        '/nr:false'
    )

    if (-not (Test-Path $recipe))
    {
        throw "The build succeeded, but the deployment recipe was not generated: $recipe"
    }

    $deployAppRecipe = Join-Path $installationPath 'Common7\IDE\DeployAppRecipe.exe'
    if (-not (Test-Path $deployAppRecipe))
    {
        throw "Could not find DeployAppRecipe.exe: $deployAppRecipe"
    }

    Write-Host 'Deploying Terminal Dev...' -ForegroundColor Cyan
    Push-Location $packageDirectory
    try
    {
        Invoke-CheckedNative $deployAppRecipe @($recipe)
    }
    finally
    {
        Pop-Location
    }

    Write-Host 'Terminal Dev was rebuilt and deployed successfully.' -ForegroundColor Green
    Write-Host 'Launch it from Start or run: wtd'
}
finally
{
    Pop-Location
}
