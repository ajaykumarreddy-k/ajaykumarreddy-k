# Download VMware Workstation Windows installers from Internet Archive.
# Requires PowerShell 5.1 or newer and Windows' built-in curl.exe.
param(
    [string]$Version,
    [switch]$Latest,
    [switch]$List,
    [switch]$Url,
    [Alias('Directory')][string]$OutDir,
    [string]$ArchiveItem = 'vmwareworkstationarchive',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Show-Usage {
    @'
Usage: .\download_workstation.ps1 [options]
With no selection option, show an interactive installer menu.
  -List                 List archived Windows installers, newest first
  -Latest               Download the newest archived release
  -Version VERSION      Download an exact version (17.6.4, 25H2, 26H1u1)
  -OutDir DIRECTORY     Destination directory (default: your Downloads folder)
  -Url                  Print the selected URL without downloading
  -ArchiveItem ITEM     Use another Internet Archive collection
  -Help                 Show this help
Examples:
  .\download_workstation.ps1 -Latest
  .\download_workstation.ps1 -Version 26H1u1
  .\download_workstation.ps1 -Latest -Url
Downloads resume from .part files and are checked against the archive's
file size and SHA-1 before the final .exe is published. These checks establish
agreement with the third-party archive, not publisher authenticity.
The script does not run installers or change Windows security settings.
'@
}

function Get-InstallerCatalog {
    param([string]$Item)
    $metadata = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $metadata = Invoke-RestMethod -Uri "https://archive.org/metadata/$Item" -UseBasicParsing -TimeoutSec 120
            break
        }
        catch {
            if ($attempt -eq 3) { throw "Could not fetch archive metadata: $($_.Exception.Message)" }
            Write-Warning 'Archive metadata request failed; retrying...'
            Start-Sleep -Seconds 3
        }
    }
    if ($null -eq $metadata -or $metadata.files -isnot [System.Array]) {
        throw 'Archive metadata has no valid file list.'
    }
    $installers = New-Object 'System.Collections.Generic.List[object]'
    $seen = @{}
    foreach ($file in $metadata.files) {
        if ($file.name -isnot [string]) { continue }
        $parts = $file.name.Split('/')
        if (@($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' -or $_ -match '[\x00-\x1f\x7f\\]' }).Count -gt 0) { continue }
        if ($parts[0] -in @('Fusion', 'Linux')) { continue }
        $filename = $parts[-1]
        if ($filename -notmatch '^VMware(?:-Workstation(?:-Full)?|Workstation)?-(?<version>[0-9]+\.[0-9]+\.[0-9]+|[0-9]{2}H[12](?:u[0-9]+)?)-(?<build>[0-9]+)\.exe$') { continue }
        $versionName = $Matches.version.ToUpperInvariant().Replace('U', 'u')
        $build = [long]$Matches.build
        if ($file.private -and [string]$file.private -ne 'false') { continue }
        if ([string]$file.size -notmatch '^[1-9][0-9]*$' -or [string]$file.sha1 -notmatch '^[a-fA-F0-9]{40}$') {
            throw "Missing or invalid size/checksum for $filename."
        }
        $category = 0
        if ($versionName -match '^(?<year>[0-9]{2})H(?<half>[12])(?:u(?<update>[0-9]+))?$') {
            $category = 1
            $major = [long]$Matches.year
            $minor = [long]$Matches.half
            $patch = 0L
            if ($Matches.update) { $patch = [long]$Matches.update }
        }
        else {
            $numbers = $versionName.Split('.')
            $major = [long]$numbers[0]
            $minor = [long]$numbers[1]
            $patch = [long]$numbers[2]
        }
        $encodedPath = ($parts | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
        $downloadUrl = "https://archive.org/download/$Item/$encodedPath"
        if ($seen.ContainsKey($downloadUrl)) { continue }
        $seen[$downloadUrl] = $true
        $installers.Add([pscustomobject]@{
            Version = $versionName
            Build = $build
            Filename = $filename
            Size = [long]$file.size
            Sha1 = ([string]$file.sha1).ToLowerInvariant()
            Url = $downloadUrl
            Category = $category
            Major = $major
            Minor = $minor
            Patch = $patch
        })
    }
    $order = @(
        @{ Expression = { $_.Category }; Descending = $true },
        @{ Expression = { $_.Major }; Descending = $true },
        @{ Expression = { $_.Minor }; Descending = $true },
        @{ Expression = { $_.Patch }; Descending = $true },
        @{ Expression = { $_.Build }; Descending = $true },
        @{ Expression = { $_.Url }; Descending = $false }
    )
    $installers | Sort-Object -Property $order
}

function Assert-RegularFilePath {
    param([string]$Path)
    $entry = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -ne $entry) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing a symbolic link or reparse point: $Path"
        }
        if ($entry -isnot [IO.FileInfo]) { throw "Destination is not a regular file: $Path" }
    }
}

function Test-InstallerFile {
    param([string]$Path, [object]$Installer)
    $entry = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $entry -or $entry.Length -ne $Installer.Size) { return $false }
    $digest = Get-FileHash -LiteralPath $Path -Algorithm SHA1
    return $digest.Hash -eq $Installer.Sha1
}

function Save-Installer {
    param([object]$Installer, [string]$Destination)
    $output = Join-Path -Path $Destination -ChildPath $Installer.Filename
    $partial = "$output.part"
    $lockPath = "$output.lock"
    foreach ($path in @($output, $partial, $lockPath)) { Assert-RegularFilePath -Path $path }
    $lock = $null
    try {
        try {
            $lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        catch {
            throw "Could not acquire the download lock. If no download is running, remove $lockPath and retry."
        }
        if (Test-Path -LiteralPath $output) {
            Write-Host 'Checking the existing installer...'
            if (-not (Test-InstallerFile -Path $output -Installer $Installer)) {
                throw "Existing file does not match archive metadata. Move it aside before retrying: $output"
            }
            Write-Host 'Existing installer matches archive size and SHA-1.'
            return $output
        }
        $bytes = 0L
        if (Test-Path -LiteralPath $partial) { $bytes = (Get-Item -LiteralPath $partial).Length }
        if ($bytes -gt $Installer.Size) { throw "Partial file is too large. Move it aside before retrying: $partial" }
        if ($bytes -lt $Installer.Size) {
            $curlExe = (Get-Command -Name curl.exe -CommandType Application -ErrorAction Stop).Source
            $curlArguments = @(
                '-q', '--fail', '--show-error', '--location', '--progress-bar',
                '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '20',
                '--speed-limit', '1024', '--speed-time', '120', '--continue-at', '-',
                '--output', $partial, $Installer.Url
            )
            for ($attempt = 1; $attempt -le 3; $attempt++) {
                Write-Host "Downloading $($Installer.Version) (attempt $attempt of 3)..."
                $savedPreference = $ErrorActionPreference
                try {
                    $ErrorActionPreference = 'Continue'
                    & $curlExe @curlArguments
                    $status = $LASTEXITCODE
                }
                finally { $ErrorActionPreference = $savedPreference }
                if ($status -eq 0) { break }
                if ($status -eq 33) { throw "Server refused resumption. Move $partial aside and retry." }
                if ($attempt -eq 3) { throw "Download failed. Partial file kept at: $partial" }
                Write-Warning "Download failed with curl exit code $status; retrying..."
                Start-Sleep -Seconds 3
            }
        }
        Write-Host 'Verifying file size and SHA-1...'
        if (-not (Test-InstallerFile -Path $partial -Installer $Installer)) {
            Remove-Item -LiteralPath $partial -Force
            throw 'Download failed verification. The corrupt partial was removed; rerun to download again.'
        }
        [IO.File]::Move($partial, $output)
        Write-Host 'Download verified against archive metadata.'
        return $output
    }
    finally {
        if ($null -ne $lock) {
            $lock.Dispose()
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    if ($Help) { Show-Usage; return }
    if ($PSVersionTable.PSVersion -lt [version]'5.1') { throw 'PowerShell 5.1 or newer is required.' }
    $modeCount = [int]$Latest.IsPresent + [int]$List.IsPresent + [int]($PSBoundParameters.ContainsKey('Version'))
    if ($modeCount -gt 1) { throw 'Use only one of -List, -Latest, or -Version.' }
    if ($List -and $Url) { throw '-Url requires a version selection, not -List.' }
    if ($ArchiveItem -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Invalid archive item identifier.' }
    if ($PSBoundParameters.ContainsKey('Version') -and $Version -notmatch '^(?:[0-9]+\.[0-9]+\.[0-9]+|[0-9]{2}H[12](?:u[0-9]+)?)$') {
        throw 'Use a version such as 17.6.4, 25H2, or 26H1u1.'
    }
    if ($modeCount -eq 0 -and $Host.Name -eq 'ConsoleHost' -and [Console]::IsInputRedirected) {
        throw 'Use -Latest, -Version, or -List when running noninteractively.'
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host "Fetching archived Windows installers ($ArchiveItem)..."
    $catalog = @(Get-InstallerCatalog -Item $ArchiveItem)
    if ($catalog.Count -eq 0) { throw 'No supported Windows installers found in the archive.' }
    if ($List) {
        $catalog | Select-Object Version, Build, @{ Name = 'MiB'; Expression = { [math]::Round($_.Size / 1MB, 1) } }, Filename
        return
    }
    $selected = $null
    if ($Latest) { $selected = $catalog[0] }
    elseif ($PSBoundParameters.ContainsKey('Version')) {
        $selected = $catalog | Where-Object { $_.Version -eq $Version } | Select-Object -First 1
        if ($null -eq $selected) { throw "Version $Version is unavailable. Use -List to see archived versions." }
    }
    else {
        for ($i = 0; $i -lt $catalog.Count; $i++) {
            Write-Host ('{0,4}. {1,-10} build {2}' -f ($i + 1), $catalog[$i].Version, $catalog[$i].Build)
        }
        while ($null -eq $selected) {
            $choice = Read-Host 'Choose an installer number (default 1, or q to quit)'
            if ($null -eq $choice -or $choice -eq 'q') { return }
            if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
            $number = 0
            if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $catalog.Count) {
                $selected = $catalog[$number - 1]
            }
            else { Write-Host 'Choose a number from the list.' }
        }
    }
    if ($Url) { $selected.Url; return }
    if ([string]::IsNullOrWhiteSpace($OutDir)) {
        $OutDir = Join-Path -Path ([Environment]::GetFolderPath('UserProfile')) -ChildPath 'Downloads'
    }
    $OutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
    $null = [IO.Directory]::CreateDirectory($OutDir)
    Write-Host "Selected Workstation $($selected.Version) (build $($selected.Build))."
    Write-Host 'Source: a third-party archive. Checksums establish agreement with the archive only.'
    Save-Installer -Installer $selected -Destination $OutDir
}
catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
