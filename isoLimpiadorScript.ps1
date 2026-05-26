# WinOS Flash - Script para modificar ISO de Windows
# Optimizacion inteligente por reglas (IA simplificada)
# Autor original: ARCTTeam
# Modificaciones: Integracion de drivers local, supresion de progreso, reglas dinamicas
# Version: WinOS Flash

param(
    [switch]$noPrompt,
    [string]$isoPath = "",
    [string]$winEdition = "",
    [string]$outputISO = "",
    [ValidateSet("yes", "no")]$useDISM = "",
    [ValidateSet("yes", "no")]$AppxRemove = "",
    [ValidateSet("yes", "no")]$CapabilitiesRemove = "",
    [ValidateSet("yes", "no")]$OnedriveRemove = "",
    [ValidateSet("yes", "no")]$EDGERemove = "",
    [ValidateSet("yes", "no")]$AIRemove = "",
    [ValidateSet("yes", "no")]$TPMBypass = "",
    [ValidateSet("yes", "no")]$UserFoldersEnable = "",
    [ValidateSet("yes", "no")]$DriverIntegrate = "",
    [ValidateSet("yes", "no")]$ESDConvert = "",
    [ValidateSet("yes", "no")]$useOscdimg = ""
)

if ($noPrompt) {
    $missing = @("isoPath","winEdition","outputISO") | Where-Object { [string]::IsNullOrWhiteSpace((Get-Variable $_).Value) }
    if ($missing) { Write-Error "Cuando se usa -noPrompt, estos parametros son obligatorios: $($missing -join ', ')"; Exit 1 }
}

if ($noPrompt) { function Pause { } }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script debe ejecutarse como Administrador. Re-lanzando con privilegios elevados..." -ForegroundColor Yellow
    
    if ($isoPath -and -not [System.IO.Path]::IsPathRooted($isoPath)) {
        $isoPath = Join-Path -Path $PSScriptRoot -ChildPath $isoPath | Resolve-Path -ErrorAction SilentlyContinue
        if (-not $isoPath) {
            $isoPath = Join-Path -Path (Get-Location).Path -ChildPath $PSBoundParameters['isoPath']
            if (Test-Path $isoPath) {
                $isoPath = (Get-Item $isoPath).FullName
            }
        }
    }
    if ($outputISO -and -not [System.IO.Path]::IsPathRooted($outputISO)) {
        $outputISO = Join-Path -Path (Get-Location).Path -ChildPath $outputISO
        $outputISO = [System.IO.Path]::GetFullPath($outputISO)
    }
    
    $params = @()
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [switch] -and $_.Value) { $params += "-$($_.Key)" }
        elseif ($_.Value -is [string] -and $_.Value) { 
            if ($_.Key -eq 'isoPath' -and $isoPath) { $params += "-$($_.Key)", "`"$isoPath`"" }
            elseif ($_.Key -eq 'outputISO' -and $outputISO) { $params += "-$($_.Key)", "`"$outputISO`"" }
            else { $params += "-$($_.Key)", "`"$($_.Value)`"" }
        }
    }    
    $argss = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $($params -join ' ')"
    if (Get-Command wt -ErrorAction SilentlyContinue) { Start-Process wt "PowerShell $argss" -Verb RunAs }
    else { Start-Process PowerShell $argss -Verb RunAs }
    Exit
}
Clear-Host
$asciiArt = @"
__        ___        ___  ____    _____ _           _     
\ \      / (_)_ __  / _ \/ ___|  |  ___| | __ _ ___| |__  
 \ \ /\ / /| | '_ \| | | \___ \  | |_  | |/ _` / __| '_ \ 
  \ V  V / | | | | | |_| |___) | |  _| | | (_| \__ \ | | |
   \_/\_/  |_|_| |_|\___/|____/  |_|   |_|\__,_|___/_| |_|
                                                                                    																					                                                                                              
"@

Write-Host $asciiArt -ForegroundColor Cyan
Start-Sleep -Milliseconds 1000
Write-Host "Iniciando Script WinOS Flash con Optimizacion Inteligente..." -ForegroundColor Green
Start-Sleep -Milliseconds 800
Write-Host "`n* Notas importantes: " -ForegroundColor Yellow
Write-Host "  1. Durante el proceso apareceran algunas ventanas emergentes."
Write-Host "  2. Se requieren privilegios de administrador."
Write-Host "  3. La optimizacion inteligente analiza cada paquete y elimina solo lo seguro."
Write-Host "  4. Para excluir un paquete, comenta la linea correspondiente en el script."
Write-Host "  5. Selecciona el archivo ISO para continuar."
Start-Sleep -Milliseconds 800

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$scriptDirectory = "$PSScriptRoot"
$logFilePath = Join-Path -Path $scriptDirectory -ChildPath 'script_log.txt'
$transcript = "$env:TEMP\transcript_$(Get-Random).txt"
Start-Transcript $transcript -Append -ErrorAction SilentlyContinue 2>&1 | Out-Null

$osInfo = Get-WmiObject -Class Win32_OperatingSystem
$logEntry = @"
$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Script started
- Launched As: $((Get-CimInstance Win32_Process -Filter "ProcessId = $PID").CommandLine)
- Windows Version: $($osInfo.Caption) $($osInfo.Version) (Build $($osInfo.BuildNumber))
- System Architecture: $($osInfo.OSArchitecture)
- Install Date: $([Management.ManagementDateTimeConverter]::ToDateTime($osInfo.InstallDate).ToString())
- System Language: $((Get-Culture).DisplayName)
- Default Language: $((Get-UICulture).DisplayName)
- Windows Directory: $($env:windir)`n
"@

$logEntry | Out-File -FilePath $logFilePath -Append

function Write-Log {
    [CmdletBinding()]
    param ([Parameter(ValueFromPipeline=$true)][object]$InputObj, [string]$msg, [switch]$Raw, [string]$Sep = " || ")
    process {
        $content = if ($msg) { $msg } elseif ($null -ne $InputObj) { if ($InputObj -is [string]) { $InputObj } else { $InputObj | Out-String } } else { return }
        if (-not $Raw -and ($content = $content.Trim())) {
            $lines = @($content -split '\n' | Where-Object { $_.Trim() })
            $cut = $lines | Where-Object { $_ -match '^\s*\+\s*(CategoryInfo|FullyQualifiedErrorId)\s*:' } | Select-Object -First 1
            if ($cut) { $lines = $lines[0..($lines.IndexOf($cut) - 1)] }
            if ($lines.Count -gt 1) {
                $processedLines = foreach ($line in $lines) {
                    $trimmed = $line.Trim()
                    if ($trimmed -match '^At\s+(.+)') { "At $($matches[1])" }
                    elseif ($trimmed -match '^\s*\+\s*~+') { continue }
                    elseif ($trimmed -match '^\s*\+\s*(.+)') { "+ " + ($matches[1] -replace '\s{2,}', ' ') }
                    elseif ($trimmed -match '^\s*\+?\s*(\w+\w+)\s*:\s*(.+)') { "$($matches[1]): $($matches[2])" }
                    elseif ($trimmed -notmatch '^-{4,}' -and $trimmed) { $trimmed -replace '\s{2,}', ' ' }
                }
                $content = $processedLines -join $Sep
            } else { $content = $content -replace '\s{2,}', ' ' }
        }
        if ($content) { Add-Content -Path "$logFilePath" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $content" }
    }
}

function Invoke-DismFailsafe {
    param([scriptblock]$PS, [scriptblock]$Dism)
    $oldProgressPref = $ProgressPreference
    $oldInfoPref = $InformationPreference
    $ProgressPreference = 'SilentlyContinue'
    $InformationPreference = 'Ignore'
    try {
        if ($useDISM -ieq "yes") {
            & $Dism 2>&1 | Write-Log
        } else {
            try { & $PS 2>&1 | Write-Log } catch { & $Dism 2>&1 | Write-Log }
        }
    } finally {
        $ProgressPreference = $oldProgressPref
        $InformationPreference = $oldInfoPref
    }
}

function Get-Confirmation { 
    param([string]$Question, [bool]$DefaultValue = $true, [string]$Description = "") 
    $defaultText = if ($DefaultValue) { "S" } else { "N" }
    $optionsText = if ($DefaultValue) { "S/n" } else { "s/N" }
    do { 
        Write-Host "$Question" -ForegroundColor Cyan -NoNewline
        if ($Description) { Write-Host " - $Description" -ForegroundColor DarkGray -NoNewline }
        Write-Host " ($optionsText): " -ForegroundColor White -NoNewline
        $answer = Read-Host 
        if ([string]::IsNullOrWhiteSpace($answer)) {
            Write-Host "Usando valor predeterminado: $defaultText" -ForegroundColor Yellow
            return $DefaultValue
        }
        $answer = $answer.ToUpper()
        if ($answer -eq 'S') { return $true }
        if ($answer -eq 'N') { return $false }
        Write-Warning "Entrada invalida. Escribe 'S' para Si, 'N' para No, o Enter para predeterminado ($defaultText)."
    } while ($true) 
}

function Get-ParameterValue {
    param( [string]$ParameterValue, [bool]$DefaultValue, [string]$Question, [string]$Description )
    if ($ParameterValue -ne "") { return $ParameterValue -eq "yes" }
    if ($noPrompt) { return $DefaultValue }
    return Get-Confirmation -Question $Question -DefaultValue $DefaultValue -Description $Description
}

function Remove-TempFiles {
    Remove-Item -Path $destinationPath -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path $installMountDir -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$env:SystemDrive\WIDTemporal" -Recurse -Force 2>&1 | Write-Log
    Stop-Transcript 2>&1 | Write-Log
    $content = Get-Content $transcript | Where-Object { $_ -notmatch "^(Windows PowerShell transcript|Start time:|Username:|RunAs User:|Configuration|Host Application:|Process ID:|PS[A-Z]|BuildVersion:|CLRVersion:|WSManStackVersion:|SerializationVersion:|Transcript started|PS C:\\|^\*{10,}|End time:)" -and $_.Trim() }
    Add-Content $logFilePath -Value ("`n" + "="*50 + "`nTerminal Snapshot - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" + "`n" + "="*50 + "`n" + ($content -join "`n"))
    Remove-Item $transcript  -Force 2>&1 | Write-Log
}

function Set-Ownership {
    param([string]$Path, [string[]]$Registry) 
    if ($Path) {
        try {
            $FullPath = [System.IO.Path]::GetFullPath($Path)
            if (-not (Test-Path -Path $FullPath)) { return $true }
            $IsFolder = (Get-Item $FullPath).PSIsContainer
            
            try {
                $Acl = Get-Acl $FullPath
                $Acl.SetOwner([System.Security.Principal.NTAccount]"Administrators")
                $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($CurrentUser, "FullControl", $(if ($IsFolder) {"ContainerInherit,ObjectInherit"} else {"None"}), "None", "Allow")
                $Acl.SetAccessRule($AccessRule)
                Set-Acl -Path $FullPath -AclObject $Acl
                
                if ($IsFolder) { Get-ChildItem -Path $FullPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { 
                        try { $ChildAcl = Get-Acl $_.FullName
                            $ChildAcl.SetOwner([System.Security.Principal.NTAccount]"Administrators")
                            $ChildAcl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($CurrentUser, "FullControl", "Allow")))
                            Set-Acl -Path $_.FullName -AclObject $ChildAcl 
                        }
                        catch {}
                    }
                }
                Write-Log -msg "[ACL] Set ownership for: $FullPath"
                return $true
            }
            catch { Write-Log -msg "ACL method failed for: $FullPath"
                try {
                    & icacls.exe "$FullPath" /setowner "Administrators" /T /C 2>&1 | Out-Null
                    & icacls.exe "$FullPath" /grant "${CurrentUser}:(F)" /T /C 2>&1 | Out-Null
                    & icacls.exe "$FullPath" /grant "Administrators:(F)" /T /C 2>&1 | Out-Null
                    Write-Log -msg "[icacls] Set ownership for: $FullPath"
                    return $true
                }
                catch { Write-Log -msg "icacls fallback failed for: $FullPath - $($_.Exception.Message)"; return $false }
            }
        } 
        catch { Write-Log -msg "Failed to own path: $Path - $($_.Exception.Message)"; return $false }
    }
    if ($Registry) {
        try {
            $sid = (New-Object System.Security.Principal.NTAccount("BUILTIN\Administrators")).Translate([System.Security.Principal.SecurityIdentifier])
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule("Administrators", "FullControl", "ContainerInherit", "None", "Allow")
            foreach ($keyPath in $Registry) {
                try {
                    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keyPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
                    if ($key) { $acl = $key.GetAccessControl()
                        $acl.SetOwner($sid)
                        $key.SetAccessControl($acl)
                        $key.Close()
                        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keyPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
                        if ($key) { $acl = $key.GetAccessControl()
                            $acl.SetAccessRule($rule)
                            $key.SetAccessControl($acl)
                            $key.Close()
                            Write-Log -msg "Set ownership for registry: $keyPath"
                        }
                    } else { Write-Log -msg "Unable to open reg-key: $keyPath" }
                } catch {}
            }
            return $true
        } catch { Write-Log -msg "Failed to own reg-key: $($_.Exception.Message)"; return $false }
    }
    return $false
}

function Set-OwnAndRemove {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $FullPath = [System.IO.Path]::GetFullPath($Path)
        if (-not (Test-Path -Path $FullPath)) { return $true }
        try {
            $ownershipResult = Set-Ownership -Path $Path
            if (-not $ownershipResult) { throw "ACL method failed" }
            Remove-Item -Path $FullPath -Force -Recurse -ErrorAction Stop
            Write-Log -msg "Removed with ACL: $FullPath"
            return $true
        } catch {
            Write-Log -msg "ACL method failed for: $FullPath"
            try {
                $IsFolder = (Get-Item $FullPath -ErrorAction Stop).PSIsContainer
                $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                if($IsFolder) { takeown /F "$FullPath" /R /D Y 2>&1 | Write-Log }
                else { takeown /F "$FullPath" /A 2>&1 | Write-Log }
                foreach ($Perm in @("*S-1-5-32-544:F", "System:F", "Administrators:F", "$CurrentUser`:F")) {
                    try {
                        if($IsFolder) { icacls "$FullPath" /grant:R "$Perm" /T /C 2>&1 | Write-Log }
                        else { icacls "$FullPath" /grant:R "$Perm" 2>&1 | Write-Log }
                        if ($LASTEXITCODE -eq 0) { break }
                    } catch { continue }
                }
                Remove-Item -Path $FullPath -Force -Recurse -ErrorAction Stop
                Write-Log -msg "Removed with icacls: $FullPath"
                return $true
            } catch { Write-Log -msg "Failed to remove: $FullPath - $($_.Exception.Message)"; return $false }
        }
    } catch { Write-Log -msg "Error processing path: $Path - $($_.Exception.Message)"; return $false }
}

function Test-InternetConnection {
    param (
        [int]$maxAttempts = 3,
        [int]$retryDelay = 5,
        [string]$hostname = "1.1.1.1",
        [int]$port = 53,
        [int]$timeout = 5000
    )
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            if ($client.ConnectAsync($hostname, $port).Wait($timeout)) {
                $client.Close(); return $true
            }
            $client.Close()
        } catch {}
        Write-Host "Conexion a Internet no disponible, reintentando en $retryDelay segundos..."
        Start-Sleep -Seconds $retryDelay
    }  
    Write-Host "`nConexion a Internet no disponible despues de $maxAttempts intentos." -ForegroundColor Red
    Write-Host "Se requiere conexion a Internet para descargar oscdimg.exe (si no esta presente)."
    Write-Host "Verifica tu conexion e intenta de nuevo."

    while ($true) {
        $internetChoice = Read-Host -Prompt "`nPresiona 't' para reintentar o 'q' para salir"
        switch ($internetChoice.ToLower()) {
            't' { return Test-InternetConnection @PSBoundParameters }
            'q' {
                Remove-TempFiles
                Exit
            }
            default { Write-Host "Entrada invalida. Escribe 't' o 'q'." }
        }
    }
}

function Get-WimDetails {
    param ( [Parameter(Mandatory = $true)][string]$MountPath )
    try {
        $out = dism /Image:$MountPath /Get-Intl /English | Out-String
        Write-Log -msg "DISM Output for Get-WimDetails:`n$out"
        $buildMatch = [regex]::Match($out, "Image Version: \d+\.\d+\.(\d+)\.\d+")
        $langMatch = [regex]::Match($out, "(?i)Default\s+system\s+UI\s+language\s*:\s*([a-z]{2}-[A-Z]{2})")
        [PSCustomObject]@{
            BuildNumber = if ($buildMatch.Success) { $buildMatch.Groups[1].Value } else { $null }
            Language = if ($langMatch.Success) { $langMatch.Groups[1].Value } else { $null }
        }
    }
    catch {
        Write-Host "Error al obtener informacion de la imagen WIM: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-ImageIndex {
    param ( [Parameter(Mandatory = $true)][string]$ImagePath )
    try {
        $out = & dism.exe /get-wiminfo /wimfile:$ImagePath /english 2>$null
        Write-Log -msg "DISM Output for Get-ImageIndex:`n$out"
        if ($LASTEXITCODE -ne 0) { throw "DISM no pudo leer el archivo de imagen: $ImagePath" }
        $images = @()
        $indexPattern = "Index\s*:\s*(\d+)"
        $namePattern = "Name\s*:\s*(.+)"
        for ($i = 0; $i -lt $out.Count; $i++) {
            if ($out[$i] -match $indexPattern) {
                $index = $matches[1]
                for ($j = $i + 1; $j -lt [Math]::Min($i + 5, $out.Count); $j++) {
                    if ($out[$j] -match $namePattern) {
                        $name = $matches[1].Trim()
                        $images += [PSCustomObject]@{
                            Index = [int]$index
                            ImageName = $name
                        }
                        break
                    }
                }
            }
        }
        return $images
    }
    catch {
        Write-Log -msg "Failed to get image information: $($_.Exception.Message)"
        return $null
    }
}

# ------------------------------------------------------------
# OPTIMIZACION INTELIGENTE POR REGLAS (IA simplificada)
# Reglas de decision para eliminar paquetes seguros
# ------------------------------------------------------------
$intelligentRules = @'
{
  "AppX": [
    { "pattern": "Microsoft.XboxIdentityProvider*", "safe": false, "conditions": [{"user_gaming": false, "safe": true}] },
    { "pattern": "Microsoft.BingWeather*", "safe": true, "minBuild": 22000, "note": "Seguro en Win11, en Win10 puede afectar widgets" },
    { "pattern": "Microsoft.Windows.DevHome*", "safe": true, "minBuild": 22621 },
    { "pattern": "Microsoft.MixedReality.Portal*", "safe": true, "editions": ["Home","Pro"] },
    { "pattern": "Microsoft.YourPhone*", "safe": true, "conditions": [{"user_mobile": false, "safe": true}] },
    { "pattern": "Microsoft.SkypeApp*", "safe": true, "always": true },
    { "pattern": "Microsoft.Teams*", "safe": true, "always": true },
    { "pattern": "Microsoft.GamingApp*", "safe": true, "conditions": [{"user_gaming": false, "safe": true}] }
  ],
  "Capabilities": [
    { "pattern": "Language.Handwriting~~~*", "safe": true, "conditions": [{"lang_not_needed": true}] },
    { "pattern": "Language.OCR~~~*", "safe": true, "conditions": [{"lang_not_needed": true}] },
    { "pattern": "Language.Speech~~~*", "safe": true, "conditions": [{"lang_not_needed": true}] },
    { "pattern": "Microsoft.Windows.WordPad*", "safe": true, "minBuild": 17000 },
    { "pattern": "Media.WindowsMediaPlayer*", "safe": true, "editions": ["Home","Pro"], "note": "Se puede reinstalar desde caracteristicas" },
    { "pattern": "Hello.Face*", "safe": false, "note": "Riesgo: rompe Windows Hello" }
  ],
  "WindowsPackage": [
    { "pattern": "Microsoft-Windows-InternetExplorer-Optional-Package*", "safe": true, "minBuild": 22000 },
    { "pattern": "Microsoft-Windows-LanguageFeatures-Handwriting-*", "safe": true, "conditions": [{"lang_not_needed": true}] },
    { "pattern": "Microsoft-Windows-MediaPlayer-Package*", "safe": true, "minBuild": 17000 },
    { "pattern": "Microsoft-Windows-TabletPCMath-Package*", "safe": true, "editions": ["Home","Pro"] }
  ]
}
'@

$rules = $intelligentRules | ConvertFrom-Json

function Test-SafeToRemove {
    param(
        [string]$PackageName,
        [string]$PackageType,
        [int]$BuildNumber,
        [string]$Edition,
        [string]$LanguageCode,
        [bool]$UserGaming = $false,
        [bool]$UserMobile = $false
    )
    
    $rulesForType = switch ($PackageType) {
        'AppX' { $rules.AppX }
        'Capability' { $rules.Capabilities }
        'WindowsPackage' { $rules.WindowsPackage }
        default { @() }
    }
    
    $matchingRule = $rulesForType | Where-Object { $PackageName -like $_.pattern } | Select-Object -First 1
    if (-not $matchingRule) {
        return $true
    }
    
    if ($matchingRule.always -eq $true) { return $true }
    
    $safe = $matchingRule.safe
    if ($matchingRule.conditions) {
        foreach ($cond in $matchingRule.conditions) {
            if ($cond.user_gaming -eq $false -and $UserGaming -eq $false) { $safe = $cond.safe }
            if ($cond.user_mobile -eq $false -and $UserMobile -eq $false) { $safe = $cond.safe }
            if ($cond.lang_not_needed -eq $true) { $safe = $true }
        }
    }
    
    if ($matchingRule.minBuild -and $BuildNumber -lt $matchingRule.minBuild) {
        $safe = $false
    }
    
    if ($matchingRule.editions -and ($matchingRule.editions -contains $Edition)) {
        $safe = $true
    } elseif ($matchingRule.editions -and ($matchingRule.editions -notcontains $Edition)) {
        $safe = $false
    }
    
    Write-Log -msg "Rule for $PackageName : safe=$safe"
    return $safe
}

function Remove-PackagesIntelligently {
    param( 
        [string[]]$Patterns, 
        [string]$SectionTitle, 
        [string]$PackageType, 
        [string]$MountPath, 
        [int]$BuildNumber,
        [string]$Edition,
        [string]$LanguageCode,
        [bool]$UserGaming,
        [bool]$UserMobile,
        [int]$TotalCount, 
        [int]$StatusColumn 
    )
    
    $config = @{
        'AppX' = @{
            GetCommand = { Get-ProvisionedAppxPackage -Path $MountPath }
            FilterProperty = 'PackageName'
            RemoveCommand = { param($item) Remove-ProvisionedAppxPackage -Path $MountPath -PackageName $item.PackageName }
            LogPrefix = 'AppX package'
        }
        'Capability' = @{
            GetCommand = { Get-WindowsCapability -Path $MountPath }
            FilterProperty = 'Name'
            RemoveCommand = { param($item) Remove-WindowsCapability -Path $MountPath -Name $item.Name }
            LogPrefix = 'capability'
        }
        'WindowsPackage' = @{
            GetCommand = { Get-WindowsPackage -Path $MountPath }
            FilterProperty = 'PackageName'
            RemoveCommand = { param($item) Remove-WindowsPackage -Path $MountPath -PackageName $item.PackageName }
            LogPrefix = 'Windows package'
        }
    }
    
    if ($SectionTitle) { Write-Host "`n$SectionTitle" -ForegroundColor Cyan; Write-Log -msg $SectionTitle }
    
    $cfg = $config[$PackageType]
    $filterProp = $cfg.FilterProperty
    $idx = 0
    
    foreach ($pattern in $Patterns) {
        $idx++
        $displayName = $pattern.TrimEnd('*')
        $counter = "[{0}/{1}]" -f $idx, $TotalCount
        $initialOutput = "  $counter $displayName"
        Write-Host $initialOutput -NoNewline
        
        try {
            $items = & $cfg.GetCommand | Where-Object { $_.$filterProp -like $pattern }
            $removedCount = 0
            foreach ($item in $items) {
                $itemName = $item.$filterProp
                $safe = Test-SafeToRemove -PackageName $itemName -PackageType $PackageType -BuildNumber $BuildNumber -Edition $Edition -LanguageCode $LanguageCode -UserGaming $UserGaming -UserMobile $UserMobile
                if ($safe) {
                    try {
                        & $cfg.RemoveCommand $item 2>&1 | Write-Log
                        $removedCount++
                    }
                    catch {
                        Write-Log -msg "Failed to remove $($cfg.LogPrefix) $itemName : $_"
                    }
                } else {
                    Write-Log -msg "Skipped (unsafe) $($cfg.LogPrefix) $itemName"
                }
            }
            $padding = $StatusColumn - $initialOutput.Length
            $spaces = ' ' * $padding
            if ($removedCount -gt 0) { Write-Host "$spaces[ELIMINADO]" -ForegroundColor Green }
            else { Write-Host "$spaces[NO ELIMINADO]" -ForegroundColor Yellow }
        }
        catch {
            Write-Log -msg "Error processing pattern '$pattern': $_"
            $padding = $StatusColumn - $initialOutput.Length
            Write-Host "$(' ' * $padding)[ERROR]" -ForegroundColor Red
        }
    }
}
# ------------------------------------------------------------

$OscdimgPath = "$env:SystemDrive\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
$Oscdimg = Join-Path -Path $OscdimgPath -ChildPath 'oscdimg.exe'

function Select-ISOFile {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
    $dialog.Filter = "Archivos ISO (*.iso)|*.iso"
    $dialog.Title = "Selecciona el archivo ISO de Windows"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    } else {
        return $null
    }
}

if ($isoPath) {$isoFilePath = $isoPath}
else {$isoFilePath = Select-ISOFile}
if ($null -eq $isoFilePath) {
    Write-Host "No se selecciono ningun archivo. Saliendo del script." -ForegroundColor Red
    Write-Log -msg "No file selected"
    Pause
    Exit
}

Write-Host "`nArchivo ISO seleccionado: " -NoNewline -ForegroundColor Cyan; Write-Host "$isoFilePath"
Write-Log -msg "ISO Path: $isoFilePath"

$mountResult = Mount-DiskImage -ImagePath "$isoFilePath" -PassThru
if ($mountResult) {
    $sourceDriveLetter = ($mountResult | Get-Volume).DriveLetter
    if ($sourceDriveLetter) {
        Write-Log -msg "Mounted ISO file to drive: $sourceDriveLetter`:"
    }
}
else {
    Write-Host "Error al montar el archivo ISO." -ForegroundColor Red
    Write-Log -msg "Failed to mount the ISO file."
    Pause
    Exit
}

$sourceDrive = "${sourceDriveLetter}:\"
$destinationPath = "$env:SystemDrive\WIDTemporal\WinOS"
$installMountDir = "$env:SystemDrive\WIDTemporal\mountdir\installWIM"

Write-Host "`nCopiando archivos desde " -NoNewline; Write-Host "`"$sourceDrive`"" -ForegroundColor Yellow -NoNewline; Write-Host " hacia " -NoNewline; Write-Host "`"$destinationPath`"" -ForegroundColor Yellow; Write-Log -msg "Copying files from $sourceDrive to $destinationPath"
Write-Host "  Copiando archivos, esto puede tardar varios minutos por favor espere..." -ForegroundColor DarkGray
try {
    if (-not (Test-Path $destinationPath)) { New-Item -ItemType Directory -Path $destinationPath -Force -EA Stop | Out-Null }
    Write-Log -msg "Starting file copy operation..."
    
    $robocopyOutput = & robocopy.exe $sourceDrive $destinationPath /E /COPY:DAT /R:3 /W:5 /MT:8 /NFL /NDL /NP 2>&1
    $robocopyExitCode = $LASTEXITCODE
    $robocopyOutput | Write-Log
    if ($robocopyExitCode -le 7) { 
        Write-Host "Copia completada exitosamente." -ForegroundColor Green
        Write-Log -msg "Copy completed (Exit: $robocopyExitCode)"
        Write-Log -msg "Removing read-only attributes..."
        Get-ChildItem -Path $destinationPath -Recurse | ForEach-Object { $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly) } | Out-Null
    }
    else { throw "Robocopy fallo: $robocopyExitCode" }
} catch { Write-Log -msg "Copy failed: $($_.Exception.Message)"; throw }

try { Dismount-DiskImage -ImagePath $isoFilePath -EA Stop | Out-Null}
catch { Write-Log -msg "Dismount failed: $($_.Exception.Message)" }

$installWimPath = Join-Path $destinationPath "sources\install.wim"
$installEsdPath = Join-Path $destinationPath "sources\install.esd"
New-Item -ItemType Directory -Path $installMountDir 2>&1 | Write-Log

if (-not (Test-Path $installWimPath)) {
    Write-Host "`ninstall.wim no encontrado. Buscando install.esd..."
    if (Test-Path $installEsdPath) {
        Write-Host "`ninstall.esd encontrado en " -NoNewline -ForegroundColor Cyan; Write-Host "$installEsdPath"
        Write-Log -msg "install.esd found. Converting..."
        Write-Host "Detalles de la imagen: " -NoNewline -ForegroundColor Cyan; Write-Host "$installEsdPath"
        try {
            $esdInfo = Get-ImageIndex -ImagePath $installEsdPath
            if (-not $esdInfo) { 
                Write-Host "Error: No se pudo obtener informacion de la imagen ESD" -ForegroundColor Red
                Remove-TempFiles
                Pause
                Exit
            }
            foreach ($image in $esdInfo) {
                Write-Host "$($image.Index). $($image.ImageName)"
            }
            if ($winEdition) {
                $matchedImage = $esdInfo | Where-Object { $_.ImageName -ieq $winEdition }
                if ($matchedImage) { $sourceIndex = $matchedImage.Index }
                else { $sourceIndex = 1 }
            }
            else { $sourceIndex = Read-Host -Prompt "`nIntroduce el indice a convertir y montar" }
            $selectedImage = $esdInfo | Where-Object { $_.Index -eq [int]$sourceIndex }
            if ($selectedImage) {
                Write-Host "`nMontando imagen: " -NoNewline -ForegroundColor Cyan; Write-Host "$sourceIndex. $($selectedImage.ImageName)"
                Write-Log -msg "Converting and Mounting image: $sourceIndex. $($selectedImage.ImageName)"
            }

            Write-Host "  Convirtiendo ESD a WIM (puede tardar varios minutos)..." -ForegroundColor DarkGray
            Invoke-DismFailsafe {Export-WindowsImage -SourceImagePath $installEsdPath -SourceIndex $sourceIndex -DestinationImagePath $installWimPath -CompressionType Maximum -CheckIntegrity} {dism /Export-Image /SourceImageFile:$installEsdPath /SourceIndex:$sourceIndex /DestinationImageFile:$installWimPath /Compress:max /CheckIntegrity}
            Write-Host "  [OK] Conversion completada" -ForegroundColor Green
            Remove-Item $installEsdPath -Force
            Write-Host "  Montando imagen convertida..." -ForegroundColor DarkGray
            Invoke-DismFailsafe {Mount-WindowsImage -ImagePath $installWimPath -Index 1 -Path $installMountDir} {dism /mount-image /imagefile:$installWimPath /index:1 /mountdir:$installMountDir}
            Write-Host "  [OK] Imagen montada" -ForegroundColor Green
            $sourceIndex = 1
        }
        catch {
            Write-Host "Error al convertir o montar la imagen ESD: $_" -ForegroundColor Red
            Write-Log -msg "Failed to mount image: $_"
            Pause
            Exit
        }
    }
    else {
        Write-Host "No se encontro install.wim ni install.esd. Asegurate de montar el ISO correcto." -ForegroundColor Red
        Write-Log -msg "Neither install.wim nor install.esd found"
        Pause
        Exit
    }
}
else {
    Write-Host "`nDetalles de la imagen: " -NoNewline -ForegroundColor Cyan; Write-Host "$installWimPath"
    Write-Log -msg "Getting image info"
    try {
        $wimInfo = Get-ImageIndex -ImagePath $installWimPath
        if (-not $wimInfo) { 
            Write-Host "Error: No se pudo obtener informacion de la imagen WIM" -ForegroundColor Red
            Remove-TempFiles
            Pause
            Exit
        }
        foreach ($image in $wimInfo) {
            Write-Host "$($image.Index). $($image.ImageName)"
        }
        if ($winEdition) {
            $matchedImage = $wimInfo | Where-Object { $_.ImageName -ieq $winEdition }
            if ($matchedImage) { $sourceIndex = $matchedImage.Index }
            else { $sourceIndex = 1 }
        }
        else { $sourceIndex = Read-Host -Prompt "`nIntroduce el indice a montar" }
        $selectedImage = $wimInfo | Where-Object { $_.Index -eq [int]$sourceIndex }
        if ($selectedImage) {
            Write-Host "`nMontando imagen: " -NoNewline -ForegroundColor Cyan; Write-Host "$sourceIndex. $($selectedImage.ImageName)"
            Write-Log -msg "Mounting image: $sourceIndex. $($selectedImage.ImageName)"
        }

        Write-Host "  Montando, por favor espere..." -ForegroundColor DarkGray
        Invoke-DismFailsafe {Mount-WindowsImage -ImagePath $installWimPath -Index $sourceIndex -Path $installMountDir} {dism /mount-image /imagefile:$installWimPath /index:$sourceIndex /mountdir:$installMountDir}
        Write-Host "  [OK] Imagen montada correctamente" -ForegroundColor Green
    }
    catch {
        Write-Host "Error al montar la imagen: $_" -ForegroundColor Red
        Write-Log -msg "Failed to mount image: $_"
        Pause
        Exit
    }
}

if (-not (Test-Path "$installMountDir\Windows")) {
    Write-Host "Error al montar la imagen. Intenta de nuevo." -ForegroundColor Red
    Write-Log -msg "Mounted image not found. Exiting"
    Remove-TempFiles
    Pause
    Exit 
}

$WimDetails = Get-WimDetails -MountPath $installMountDir
if (-not $WimDetails -or -not $WimDetails.BuildNumber -or -not $WimDetails.Language) {
    Write-Host "Error: No se pudo obtener informacion de la imagen WIM montada" -ForegroundColor Red
    Remove-TempFiles
    Pause
    Exit
}
$langCode = $WimDetails.Language; Write-Log -msg "Detected Language: $langCode"
$buildNumber = $WimDetails.BuildNumber; Write-Log -msg "Detected Build Number: $buildNumber"
$editionName = $selectedImage.ImageName

Write-Host
$DoAppxRemove = Get-ParameterValue -ParameterValue $AppxRemove -DefaultValue $true -Question "Eliminar paquetes innecesarios?" -Description "Recomendado: Elimina aplicaciones bloatware"
$DoCapabilitiesRemove = Get-ParameterValue -ParameterValue $CapabilitiesRemove -DefaultValue $true -Question "Eliminar caracteristicas innecesarias?" -Description "Recomendado: Elimina caracteristicas opcionales de Windows"
$DoOnedriveRemove = Get-ParameterValue -ParameterValue $OnedriveRemove -DefaultValue $true -Question "Eliminar OneDrive?" -Description "Opcional: Elimina completamente OneDrive"
$DoEDGERemove = Get-ParameterValue -ParameterValue $EDGERemove -DefaultValue $true -Question "Eliminar Microsoft Edge?" -Description "Opcional: Elimina componentes de Edge (Rompe Widgets)"
$DoAIRemove = Get-ParameterValue -ParameterValue $AIRemove -DefaultValue $true -Question "Eliminar componentes de IA?" -Description "Opcional: Elimina todo lo relacionado con IA"
$DoTPMBypass = Get-ParameterValue -ParameterValue $TPMBypass -DefaultValue $false -Question "Omitir verificacion TPM?" -Description "Solo si es necesario para hardware antiguo"
$DoUserFoldersEnable = Get-ParameterValue -ParameterValue $UserFoldersEnable -DefaultValue $true -Question "Habilitar carpetas de usuario?" -Description "Recomendado: Habilita Escritorio, Documentos, etc."
$DoDriverIntegrate = Get-ParameterValue -ParameterValue $DriverIntegrate -DefaultValue $false -Question "Integrar drivers desde carpeta local?" -Description "Opcional: Selecciona una carpeta con drivers (ej. Intel RST/VMD)"
$DoESDConvert = Get-ParameterValue -ParameterValue $ESDConvert -DefaultValue $false -Question "Comprimir el ISO?" -Description "Recomendado pero lento: Reduce el tamano del ISO"
$DoUseOscdimg = Get-ParameterValue -ParameterValue $useOscdimg -DefaultValue $true -Question "Usar Oscdimg para crear el ISO?" -Description "Recomendado: Oscdimg es mas confiable"

$userGaming = Get-Confirmation -Question "Usaras esta PC principalmente para juegos?" -DefaultValue $false -Description "Si respondes Si, se conservaran componentes de Xbox"
$userMobile = Get-Confirmation -Question "Usaras la funcionalidad 'Tu Telefono' con un movil?" -DefaultValue $false -Description "Si respondes Si, se conservara YourPhone"

$appxPatternsToRemove = @(
    "Microsoft.Microsoft3DViewer*","Microsoft.WindowsAlarms*","Microsoft.BingNews*","Microsoft.BingSearch*","Microsoft.BingWeather*",
    "Windows.CBSPreview*","Clipchamp.Clipchamp*","Microsoft.549981C3F5F10*","MicrosoftWindows.CrossDevice*","Microsoft.Windows.DevHome*",
    "MicrosoftCorporationII.MicrosoftFamily*","Microsoft.WindowsFeedbackHub*","Microsoft.GetHelp*","Microsoft.Getstarted*",
    "Microsoft.WindowsCommunicationsapps*","Microsoft.WindowsMaps*","Microsoft.MixedReality.Portal*","Microsoft.ZuneMusic*",
    "Microsoft.MicrosoftOfficeHub*","Microsoft.Office.OneNote*","Microsoft.OutlookForWindows*","Microsoft.MSPaint*","Microsoft.People*",
    "Microsoft.Windows.PeopleExperienceHost*","Microsoft.YourPhone*","Microsoft.PowerAutomateDesktop*","MicrosoftCorporationII.QuickAssist*",
    "Microsoft.SkypeApp*","Microsoft.MicrosoftStickyNotes*","Microsoft.MicrosoftSolitaireCollection*","Microsoft.Teams*","MSTeams*",
    "Microsoft.Windows.Teams*","Microsoft.Todos*","Microsoft.ZuneVideo*","Microsoft.Wallet*","Microsoft.GamingApp*","Microsoft.XboxApp*",
    "Microsoft.XboxGameOverlay*","Microsoft.XboxGamingOverlay*","Microsoft.XboxSpeechToTextOverlay*","Microsoft.Xbox.TCUI*"
)
$capabilitiesToRemove = @(
    "Browser.InternetExplorer*","Internet-Explorer*","App.StepsRecorder*","Language.Handwriting~~~$langCode*","Language.OCR~~~$langCode*",
    "Language.Speech~~~$langCode*","Language.TextToSpeech~~~$langCode*","Microsoft.Windows.WordPad*","MathRecognizer*",
    "Microsoft.Windows.PowerShell.ISE*","Media.WindowsMediaPlayer*"
)
$windowsPackagesToRemove = @(
    "Microsoft-Windows-InternetExplorer-Optional-Package*",
    "Microsoft-Windows-LanguageFeatures-Handwriting-$langCode-Package*",
    "Microsoft-Windows-LanguageFeatures-OCR-$langCode-Package*",
    "Microsoft-Windows-LanguageFeatures-Speech-$langCode-Package*",
    "Microsoft-Windows-LanguageFeatures-TextToSpeech-$langCode-Package*",
    "Microsoft-Windows-Wallpaper-Content-Extended-FoD-Package*",
    "Microsoft-Windows-WordPad-FoD-Package*",
    "Microsoft-Windows-MediaPlayer-Package*",
    "Microsoft-Windows-TabletPCMath-Package*",
    "Microsoft-Windows-StepsRecorder-Package*"
)

$allPatterns = $appxPatternsToRemove + $capabilitiesToRemove + $windowsPackagesToRemove
$maxLength = ($allPatterns | ForEach-Object { $_.TrimEnd('*').Length } | Measure-Object -Maximum).Maximum
$statusColumn = $maxLength + 18

if ($DoAppxRemove) {
    Remove-PackagesIntelligently -Patterns $appxPatternsToRemove -SectionTitle "Eliminando paquetes provisionados (con IA):" -PackageType "AppX" -MountPath $installMountDir -BuildNumber $buildNumber -Edition $editionName -LanguageCode $langCode -UserGaming $userGaming -UserMobile $userMobile -TotalCount $appxPatternsToRemove.Count -StatusColumn $statusColumn
} else {
    Write-Log -msg "Skipped Package Removal"
}

if ($DoCapabilitiesRemove) {
    $capabilitiesAndPackagesTotal = $capabilitiesToRemove.Count + $windowsPackagesToRemove.Count
    Write-Host "`nEliminando caracteristicas innecesarias, por favor espere..." -ForegroundColor Cyan
    Remove-PackagesIntelligently -Patterns $capabilitiesToRemove -SectionTitle "" -PackageType "Capability" -MountPath $installMountDir -BuildNumber $buildNumber -Edition $editionName -LanguageCode $langCode -UserGaming $userGaming -UserMobile $userMobile -TotalCount $capabilitiesAndPackagesTotal -StatusColumn $statusColumn
    Remove-PackagesIntelligently -Patterns $windowsPackagesToRemove -SectionTitle "" -PackageType "WindowsPackage" -MountPath $installMountDir -BuildNumber $buildNumber -Edition $editionName -LanguageCode $langCode -UserGaming $userGaming -UserMobile $userMobile -TotalCount $capabilitiesAndPackagesTotal -StatusColumn $statusColumn
} else { Write-Log -msg "Skipped Features Removal" }

function Enable-Privilege {
    param([ValidateSet('SeAssignPrimaryTokenPrivilege', 'SeAuditPrivilege', 'SeBackupPrivilege', 'SeChangeNotifyPrivilege', 'SeCreateGlobalPrivilege', 'SeCreatePagefilePrivilege', 'SeCreatePermanentPrivilege', 'SeCreateSymbolicLinkPrivilege', 'SeCreateTokenPrivilege', 'SeDebugPrivilege', 'SeEnableDelegationPrivilege', 'SeImpersonatePrivilege', 'SeIncreaseBasePriorityPrivilege', 'SeIncreaseQuotaPrivilege', 'SeIncreaseWorkingSetPrivilege', 'SeLoadDriverPrivilege', 'SeLockMemoryPrivilege', 'SeMachineAccountPrivilege', 'SeManageVolumePrivilege', 'SeProfileSingleProcessPrivilege', 'SeRelabelPrivilege', 'SeRemoteShutdownPrivilege', 'SeRestorePrivilege', 'SeSecurityPrivilege', 'SeShutdownPrivilege', 'SeSyncAgentPrivilege', 'SeSystemEnvironmentPrivilege', 'SeSystemProfilePrivilege', 'SeSystemtimePrivilege', 'SeTakeOwnershipPrivilege', 'SeTcbPrivilege', 'SeTimeZonePrivilege', 'SeTrustedCredManAccessPrivilege', 'SeUndockPrivilege', 'SeUnsolicitedInputPrivilege')]$Privilege, $ProcessId = $pid, [Switch]$Disable)
    $def = @'
    using System;using System.Runtime.InteropServices;public class AdjPriv{[DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true)]internal static extern bool AdjustTokenPrivileges(IntPtr htok,bool disall,ref TokPriv1Luid newst,int len,IntPtr prev,IntPtr relen);[DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true)]internal static extern bool OpenProcessToken(IntPtr h,int acc,ref IntPtr phtok);[DllImport("advapi32.dll",SetLastError=true)]internal static extern bool LookupPrivilegeValue(string host,string name,ref long pluid);[StructLayout(LayoutKind.Sequential,Pack=1)]internal struct TokPriv1Luid{public int Count;public long Luid;public int Attr;}public static bool EnablePrivilege(long processHandle,string privilege,bool disable){var tp=new TokPriv1Luid();tp.Count=1;tp.Attr=disable?0:2;IntPtr htok=IntPtr.Zero;if(!OpenProcessToken(new IntPtr(processHandle),0x28,ref htok))return false;if(!LookupPrivilegeValue(null,privilege,ref tp.Luid))return false;return AdjustTokenPrivileges(htok,false,ref tp,0,IntPtr.Zero,IntPtr.Zero);}}
'@
    (Add-Type $def -PassThru -EA SilentlyContinue)[0]::EnablePrivilege((Get-Process -id $ProcessId).Handle, $Privilege, $Disable)
}
Enable-Privilege SeTakeOwnershipPrivilege | Out-Null

if ($DoOnedriveRemove) {
    Write-Host ("`n[INFO] Eliminando OneDrive...") -ForegroundColor Cyan
    Write-Log -msg "Defining OneDrive Setup file paths"
    $oneDriveSetupPath1 = Join-Path -Path $installMountDir -ChildPath 'Windows\System32\OneDriveSetup.exe'
    $oneDriveSetupPath2 = Join-Path -Path $installMountDir -ChildPath 'Windows\SysWOW64\OneDriveSetup.exe'
    $oneDriveShortcut = Join-Path -Path $installMountDir -ChildPath 'Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk'

    Write-Log -msg "Removing OneDrive"
    Set-OwnAndRemove -Path $oneDriveSetupPath1 | Out-Null
    Set-OwnAndRemove -Path $oneDriveSetupPath2 | Out-Null
    Set-OwnAndRemove -Path $oneDriveShortcut | Out-Null

    Write-Host ("[OK] OneDrive eliminado") -ForegroundColor Green
    Write-Log -msg "OneDrive removed successfully"
} else {
    Write-Log -msg "OneDrive removal skipped"
}

if ($DoEDGERemove) {
    Write-Host ("`n[INFO] Eliminando EDGE...") -ForegroundColor Cyan
    Write-Log -msg "Removing EDGE"
    
    dism /image:"$installMountDir" /Remove-Edge 2>&1 | Write-Log
    
    $EDGEpatterns = @(
        "Microsoft.MicrosoftEdge.Stable*",
        "Microsoft.MicrosoftEdgeDevToolsClient*", 
        "Microsoft.Win32WebViewHost*",
        "MicrosoftWindows.Client.WebExperience*"
    )

    foreach ($pattern in $EDGEpatterns) {
        $matchedPackages = Get-ProvisionedAppxPackage -Path $installMountDir | 
        Where-Object { $_.PackageName -like $pattern }
        foreach ($package in $matchedPackages) {
            Invoke-DismFailsafe {Remove-ProvisionedAppxPackage -Path $installMountDir -PackageName $package.PackageName} {dism /image:$installMountDir /Remove-ProvisionedAppxPackage /PackageName:$($package.PackageName)}
        }
    }

    Get-WindowsCapability -Path $installMountDir | Where-Object { $_.Name -like "Edge.Webview2.Platform*" } |
        ForEach-Object { Invoke-DismFailsafe {Remove-WindowsCapability -Path $installMountDir -Name $_.Name} {dism /image:$installMountDir /Remove-Capability /CapabilityName:$($_.Name)} }

    Get-WindowsPackage -Path $installMountDir | Where-Object { $_.PackageName -like "Microsoft-Edge-WebView-FOD-Package*" } |
        ForEach-Object { Invoke-DismFailsafe {Remove-WindowsPackage -Path $installMountDir -PackageName $_.PackageName} {dism /image:$installMountDir /Remove-Package /PackageName:$($_.PackageName)} }

    try {
        reg load HKLM\zSOFTWARE "$installMountDir\Windows\System32\config\SOFTWARE" 2>&1 | Write-Log
        reg load HKLM\zSYSTEM "$installMountDir\Windows\System32\config\SYSTEM" 2>&1 | Write-Log
        reg load HKLM\zNTUSER "$installMountDir\Users\Default\ntuser.dat" 2>&1 | Write-Log
        reg load HKLM\zDEFAULT "$installMountDir\Windows\System32\config\default" 2>&1 | Write-Log
          
        reg delete "HKLM\zSOFTWARE\Microsoft\EdgeUpdate" /f 2>&1 | Write-Log
        reg delete "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /f 2>&1 | Write-Log
        reg delete "HKLM\zDEFAULT\Software\Microsoft\EdgeUpdate" /f 2>&1 | Write-Log
        reg delete "HKLM\zNTUSER\Software\Microsoft\EdgeUpdate" /f 2>&1 | Write-Log
        reg delete "HKLM\zSOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}" /f 2>&1 | Write-Log
        reg delete "HKLM\zSOFTWARE\WOW6432Node\Microsoft\Edge" /f 2>&1 | Write-Log
        reg delete "HKLM\zSOFTWARE\WOW6432Node\Microsoft\EdgeUpdate" /f 2>&1 | Write-Log
        reg delete "HKLM\zSYSTEM\CurrentControlSet\Services\edgeupdate" /f 2>&1 | Write-Log
        reg delete "HKLM\zSYSTEM\ControlSet001\Services\edgeupdate" /f 2>&1 | Write-Log
        reg delete "HKLM\zSYSTEM\CurrentControlSet\Services\edgeupdatem" /f 2>&1 | Write-Log
        reg delete "HKLM\zSYSTEM\ControlSet001\Services\edgeupdatem" /f 2>&1 | Write-Log
        reg delete "HKLM\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" /f 2>&1 | Write-Log
        reg delete "HKLM\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\MicrosoftEdge\Main" /v "AllowPrelaunch" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v "AllowPrelaunch" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zNTUSER\Software\Microsoft\MicrosoftEdge\Main" /v "AllowPrelaunch" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zNTUSER\Software\Policies\Microsoft\MicrosoftEdge\Main" /v "AllowPrelaunch" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\MicrosoftEdge\TabPreloader" /v "AllowTabPreloading" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" /v "AllowTabPreloading" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zNTUSER\Software\Microsoft\MicrosoftEdge\TabPreloader" /v "AllowTabPreloading" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zNTUSER\Software\Policies\Microsoft\MicrosoftEdge\TabPreloader" /v "AllowTabPreloading" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Policies\Microsoft\EdgeUpdate" /v "UpdateDefault" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        
        $registryKeys = @(
            "HKLM\zSOFTWARE\Microsoft\EdgeUpdate",
            "HKLM\zSOFTWARE\Policies\Microsoft\EdgeUpdate",
            "HKLM\zSOFTWARE\WOW6432Node\Microsoft\EdgeUpdate",
            "HKLM\zNTUSER\Software\Microsoft\EdgeUpdate",
            "HKLM\zNTUSER\Software\Policies\Microsoft\EdgeUpdate"
        )
        foreach ($key in $registryKeys) {
            reg add "$key" /v "DoNotUpdateToEdgeWithChromium" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "$key" /v "UpdaterExperimentationAndConfigurationServiceControl" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "$key" /v "InstallDefault" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        }
    }
    catch {
        Write-Log -msg "Error modifying registry: $_"
    }
    finally {
        reg unload HKLM\zSOFTWARE 2>&1 | Write-Log
        reg unload HKLM\zSYSTEM 2>&1 | Write-Log
        reg unload HKLM\zNTUSER 2>&1 | Write-Log
        reg unload HKLM\zDEFAULT 2>&1 | Write-Log
    }

    Remove-Item -Path "$installMountDir\Program Files\Microsoft\Edge" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\Program Files\Microsoft\EdgeCore" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\Program Files\Microsoft\EdgeUpdate" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\Program Files\Microsoft\EdgeWebView" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\Program Files (x86)\Microsoft\Edge" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\Program Files (x86)\Microsoft\EdgeCore" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\Program Files (x86)\Microsoft\EdgeWebView" -Recurse -Force 2>&1 | Write-Log
    Remove-Item -Path "$installMountDir\ProgramData\Microsoft\EdgeUpdate" -Recurse -Force 2>&1 | Write-Log
    Get-ChildItem "$installMountDir\ProgramData\Microsoft\Windows\AppRepository\Packages\Microsoft.MicrosoftEdge.Stable*" -Directory | ForEach-Object { Set-OwnAndRemove -Path $_.FullName } 2>&1 | Write-Log
    Get-ChildItem "$installMountDir\ProgramData\Microsoft\Windows\AppRepository\Packages\Microsoft.MicrosoftEdgeDevToolsClient*" -Directory | ForEach-Object { Set-OwnAndRemove -Path $_.FullName } 2>&1 | Write-Log
    Set-OwnAndRemove -Path (Join-Path -Path $installMountDir -ChildPath 'Windows\System32\Microsoft-Edge-WebView') | Out-Null
    Get-Item (Join-Path -Path $installMountDir -ChildPath 'Windows\SystemApps\Microsoft.Win32WebViewHost*') -ErrorAction SilentlyContinue | ForEach-Object { Set-OwnAndRemove -Path $_.FullName | Out-Null }

    Get-ChildItem -Path "$installMountDir\Windows\System32\Tasks\MicrosoftEdge*" | Where-Object { $_ } | ForEach-Object { Set-OwnAndRemove -Path $_ } 2>&1 | Write-Log
    
    if ($buildNumber -lt 22000) {
        Get-ChildItem -Path "$installMountDir\Windows\SystemApps\Microsoft.MicrosoftEdge*" | Where-Object { $_ } | ForEach-Object { Set-OwnAndRemove -Path $_ } 2>&1 | Write-Log
    }
    
    Write-Host ("[OK] EDGE ha sido eliminado") -ForegroundColor Green
    Write-Log -msg "Microsoft Edge removal completed"
} else {
    Write-Log -msg "Edge removal cancelled"
}

if ($buildNumber -ge 22000) {
    if ($DoAIRemove) {
        Write-Host ("`n[INFO] Eliminando componentes de IA...") -ForegroundColor Cyan
        Write-Log -msg "Removing AI components"
        
        $AIpatterns = @(
            "Microsoft.Windows.Copilot*",
            "Microsoft.Copilot*"
        )
        foreach ($pattern in $AIpatterns) {
            $matchedPackages = Get-ProvisionedAppxPackage -Path $installMountDir | 
            Where-Object { $_.PackageName -like $pattern }
            foreach ($package in $matchedPackages) {
                Invoke-DismFailsafe {Remove-ProvisionedAppxPackage -Path $installMountDir -PackageName $package.PackageName} {dism /image:$installMountDir /Remove-ProvisionedAppxPackage /PackageName:$($package.PackageName)}
            }
        }

        $dllfiles = @('System32', 'SysWOW64') | ForEach-Object {
            Join-Path $installMountDir "Windows\$_\Windows.AI.MachineLearning.dll"
            Join-Path $installMountDir "Windows\$_\Windows.AI.MachineLearning.Preview.dll"
        }
        $dllfiles += Join-Path $installMountDir "Windows\System32\SettingsHandlers_Copilot.dll"
        $dllfiles | Where-Object { Test-Path $_ } | ForEach-Object {
            Set-Ownership -Path $_ | Out-Null
            try { Rename-Item $_ ($_ + ".bak") -Force -ErrorAction Stop 2>&1 | Write-Log }
            catch {
                Write-Log -msg "Rename failed for $_. Attempting to delete..."
                Set-OwnAndRemove -Path $_ 2>&1 | Write-Log
            }
        }

        try {
            reg load HKLM\zSOFTWARE "$installMountDir\Windows\System32\config\SOFTWARE" 2>&1 | Write-Log
            reg load HKLM\zSYSTEM "$installMountDir\Windows\System32\config\SYSTEM" 2>&1 | Write-Log
            reg load HKLM\zNTUSER "$installMountDir\Users\Default\ntuser.dat" 2>&1 | Write-Log

            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\WindowsNotepad" /v "DisableAIFeatures" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" /v "DisableCocreator" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" /v "DisableImageCreator" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v "LetAppsAccessSystemAIModels" /t REG_DWORD /d "2" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v "LetAppsAccessGenerativeAI" /t REG_DWORD /d "2" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\generativeAI" /v "Value" /t REG_SZ /d "Deny" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v "HubsSidebarEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v "CopilotPageContext" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Edge" /v "CopilotCDPPageContext" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableClickToDo" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "DisableWSAIFabricSvc" /t REG_SZ /d 'reg add "HKLM\SYSTEM\CurrentControlSet\Services\WSAIFabricSvc" /v "Start" /t REG_DWORD /d "4" /f'
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "StopWSAIFabricSvc" /t REG_SZ /d "net stop WSAIFabricSvc"
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "SettingsPageVisibility" /t REG_SZ /d "hide:aicomponents" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\WindowsCopilot" /v "AllowCopilotRuntime" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins" /v "CopilotPWAPin" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins" /v "RecallPin" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "AllowRecallEnablement" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "TurnOffSavingSnapshots" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableSettingsAgent" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\Shell\Copilot" /v "IsCopilotAvailable" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\Shell\Copilot" /v "CopilotDisabledReason" /t REG_SZ /d "FeatureIsDisabled" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Policies\Microsoft\Windows\WindowsAI" /v "AllowRecallEnablement" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Policies\Microsoft\Windows\WindowsAI" /v "TurnOffSavingSnapshots" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Policies\Microsoft\Windows\WindowsAI" /v "DisableSettingsAgent" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Microsoft\Windows\Shell\Copilot" /v "IsCopilotAvailable" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
            reg add "HKLM\zNTUSER\Software\Microsoft\Windows\Shell\Copilot" /v "CopilotDisabledReason" /t REG_SZ /d "FeatureIsDisabled" /f 2>&1 | Write-Log
            reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\WindowsAI" /f 2>&1 | Write-Log
            Set-OwnAndRemove -Path "$installMountDir\Windows\System32\Tasks\Microsoft\Windows\WindowsAI" | Out-Null
            reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "DisableRecall" /t REG_SZ /d "dism.exe /online /disable-feature /FeatureName:recall" /f 2>&1 | Write-Log
        }
        catch {
            Write-Log -msg "Error modifying registry: $_"
        }
        finally {
            reg unload HKLM\zSOFTWARE 2>&1 | Write-Log
            reg unload HKLM\zSYSTEM 2>&1 | Write-Log
            reg unload HKLM\zNTUSER 2>&1 | Write-Log
        }
        Write-Host ("[OK] Componentes de IA eliminados") -ForegroundColor Green
        Write-Log -msg "AI Components removal completed"
    } else {
        Write-Log -msg "AI Components removal skipped"
    }
}

Write-Host ("`n[INFO] Cargando Registro...") -ForegroundColor Cyan
Write-Log -msg "Loading registry"
reg load HKLM\zCOMPONENTS "$installMountDir\Windows\System32\config\COMPONENTS" 2>&1 | Write-Log
reg load HKLM\zDEFAULT "$installMountDir\Windows\System32\config\default" 2>&1 | Write-Log
reg load HKLM\zNTUSER "$installMountDir\Users\Default\ntuser.dat" 2>&1 | Write-Log
reg load HKLM\zSOFTWARE "$installMountDir\Windows\System32\config\SOFTWARE" 2>&1 | Write-Log
reg load HKLM\zSYSTEM "$installMountDir\Windows\System32\config\SYSTEM" 2>&1 | Write-Log

Set-Ownership -Registry @("zSOFTWARE\Microsoft\Windows\CurrentVersion\Communications", "zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks", "zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows", "zSOFTWARE\Microsoft\WindowsRuntime\Server\Windows.Gaming.GameBar.Internal.PresenceWriterServer") | Out-Null

Write-Host ("[OK] Registro cargado") -ForegroundColor Green

Write-Host ("`n[INFO] Realizando ajustes en el Registro...") -ForegroundColor Cyan

Write-Host -NoNewline ("  Deshabilitando aplicaciones patrocinadas".PadRight($statusColumn))
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "OemPreInstalledAppsEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "ConfigureStartPins" /t REG_SZ /d '{\"pinnedList\": [{}]}' /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContentEnabled" /t REG_SZ /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContentEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-310093Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338393Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353694Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353696Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "ContentDeliveryAllowed" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEverEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SoftLandingEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg delete "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions" /f 2>&1 | Write-Log
reg delete "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando telemetria".PadRight($statusColumn))
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Personalization\Settings" /v "AcceptedPrivacyPolicy" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v "HasAccepted" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\InputPersonalization" /v "RestrictImplicitInkCollection" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\InputPersonalization" /v "RestrictImplicitTextCollection" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore" /v "HarvestContacts" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zSYSTEM\ControlSet001\Services\dmwappushservice" /v "Start" /t REG_DWORD /d "4" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando aceleracion del mouse".PadRight($statusColumn))
reg add "HKLM\zNTUSER\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando Meet Now".PadRight($statusColumn))
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "HideSCAMeetNow" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "AllowOnlineTips" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando anuncios y contenido no deseado".PadRight($statusColumn))
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v "Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableConsumerAccountStateContent" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableCloudOptimizedContent" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_IrisRecommendations" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v "EnableFeeds" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d "200" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\MRT" /v "DontOfferThroughWUAU" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Teams" /v "DisableInstallation" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Mail" /v "PreventRun" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando cifrado Bitlocker".PadRight($statusColumn))
reg add "HKLM\zSYSTEM\ControlSet001\Control\BitLocker" /v "PreventDeviceEncryption" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Eliminando basura de OneDrive".PadRight($statusColumn))
reg delete "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableLibrariesDefaultSaveToOneDrive" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\OneDrive" /v "KFMBlockOptIn" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando GameDVR y componentes".PadRight($statusColumn))
reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zNTUSER\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f 2>&1 | Write-Log
reg add "HKLM\zSYSTEM\ControlSet001\Services\BcastDVRUserService" /v "Start" /t REG_DWORD /d 4 /f 2>&1 | Write-Log
reg add "HKLM\zSYSTEM\ControlSet001\Services\GameBarPresenceWriter" /v "Start" /t REG_DWORD /d 4 /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Eliminando ventana emergente de Gamebar".PadRight($statusColumn))
reg add "HKLM\zNTUSER\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d 0 /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Ajustando configuracion OOBE".PadRight($statusColumn))
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\OOBE" /v "DisablePrivacyExperience" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "BypassNRO" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "BypassNROGatherOptions" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando basura innecesaria".PadRight($statusColumn))
reg delete "HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" /v "workCompleted" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg delete "HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate" /v "workCompleted" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v "ConfigureChatAutoInstall" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v "ChatIcon" /t REG_DWORD /d "3" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

Write-Host -NoNewline ("  Deshabilitando tareas programadas".PadRight($statusColumn))
$win24H2 = (Get-ItemProperty -Path 'Registry::HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion -eq '24H2'
if ($win24H2) {
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{780E487D-C62F-4B55-AF84-0E38116AFE07}" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{FD607F42-4541-418A-B812-05C32EBA8626}" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{E4FED5BC-D567-4044-9642-2EDADF7DE108}" /f 2>&1 | Write-Log
    Set-OwnAndRemove -Path "$installMountDir\Windows\System32\Tasks\Microsoft\Windows\Customer Experience Improvement Program" | Out-Null
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{E292525C-72F1-482C-8F35-C513FAA98DAE}" /f 2>&1 | Write-Log
    Set-OwnAndRemove -Path "$installMountDir\Windows\System32\Tasks\Microsoft\Windows\Application Experience\ProgramDataUpdater" | Out-Null
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{3047C197-66F1-4523-BA92-6C955FEF9E4E}" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{A0C71CB8-E8F0-498A-901D-4EDA09E07FF4}" /f 2>&1 | Write-Log
    Set-OwnAndRemove -Path "$installMountDir\Windows\System32\Tasks\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" | Out-Null
}
else {
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{4738DE7A-BCC1-4E2D-B1B0-CADB044BFA81}" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{6FAC31FA-4A85-4E64-BFD5-2154FF4594B3}" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{FC931F16-B50A-472E-B061-B6F79A71EF59}" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Customer Experience Improvement Program" /f 2>&1 | Write-Log
    Set-OwnAndRemove -Path "$installMountDir\Windows\System32\Tasks\Microsoft\Windows\Customer Experience Improvement Program" | Out-Null
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{0671EB05-7D95-4153-A32B-1426B9FE61DB}" /f 2>&1 | Write-Log
    Set-OwnAndRemove -Path "$installMountDir\Windows\System32\Tasks\Microsoft\Windows\Application Experience\ProgramDataUpdater" | Out-Null
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{0600DD45-FAF2-4131-A006-0B17509B9F78}" /f 2>&1 | Write-Log
    Set-OwnAndRemove -Path "$installMountDir\Windows\System32\Tasks\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" | Out-Null
}
reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Application Experience\PcaPatchDbTask" /f 2>&1 | Write-Log
reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Application Experience\MareBackup" /f 2>&1 | Write-Log
reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /f 2>&1 | Write-Log
reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Autochk\Proxy" /f 2>&1 | Write-Log
reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /f 2>&1 | Write-Log
reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /f 2>&1 | Write-Log
Write-Host "[HECHO]" -ForegroundColor Green

if ($DoTPMBypass) {
    Write-Host ("`n[INFO] Deshabilitando verificacion TPM...") -ForegroundColor Cyan
    Write-Host ("  Esto puede tomar algo de tiempo") -ForegroundColor DarkGray
    Write-Log -msg "Disabling TPM Check"
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassDiskCheck" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    reg add "HKLM\zSYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    
    reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
    reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
    reg add "HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
    reg add "HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
    reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "HideUnsupportedHardwareNotifications" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\CompatMarkers" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Shared" /f 2>&1 | Write-Log
    reg delete "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators" /f 2>&1 | Write-Log
    reg add "HKLM\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\HwReqChk" /v "HwReqChkVars" /t REG_MULTI_SZ /d "SQ_SecureBootCapable=TRUE\0SQ_SecureBootEnabled=TRUE\0SQ_TpmVersion=2\0SQ_RamMB=8192" /f 2>&1 | Write-Log
    reg add "HKLM\zNTUSER\Software\Microsoft\PCHC" /v "UpgradeEligibility" /t REG_DWORD /d "1" /f 2>&1 | Write-Log

    $apprdllPath = Join-Path -Path $destinationPath -ChildPath "sources\appraiserres.dll"
    Set-OwnAndRemove -Path "$apprdllPath" | Out-Null
    New-Item -Path $apprdllPath -ItemType File -Force 2>&1 | Write-Log
    try {
        $ProgressPreference = 'SilentlyContinue'
        $bootWimPath = Join-Path $destinationPath "sources\boot.wim"
        $bootMountDir = "$env:SystemDrive\WIDTemporal\mountdir\bootWIM"
        New-Item -ItemType Directory -Path $bootMountDir 2>&1 | Write-Log
        Invoke-DismFailsafe {Mount-WindowsImage -ImagePath $bootWimPath -Index 2 -Path $bootMountDir} {dism /mount-image /imagefile:$bootWimPath /index:2 /mountdir:$bootMountDir}

        reg load HKLM\xDEFAULT "$bootMountDir\Windows\System32\config\default" 2>&1 | Write-Log
        reg load HKLM\xNTUSER "$bootMountDir\Users\Default\ntuser.dat" 2>&1 | Write-Log
        reg load HKLM\xSYSTEM "$bootMountDir\Windows\System32\config\SYSTEM" 2>&1 | Write-Log
        reg load HKLM\xSOFTWARE "$bootMountDir\Windows\System32\config\SOFTWARE" 2>&1 | Write-Log

        reg add "HKLM\xSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f 2>&1 | Write-Log
        reg add "HKLM\xSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f 2>&1 | Write-Log
        reg add "HKLM\xSYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d 1 /f 2>&1 | Write-Log
        reg add "HKLM\xSYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d 1 /f 2>&1 | Write-Log
        reg add "HKLM\xSYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f 2>&1 | Write-Log
        reg add "HKLM\xSYSTEM\Setup\LabConfig" /v "BypassDiskCheck" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\xSYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d 1 /f 2>&1 | Write-Log
        reg add "HKLM\xDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\xDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\xSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "HideUnsupportedHardwareNotifications" /t REG_DWORD /d "1" /f 2>&1 | Write-Log
        reg add "HKLM\xSOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\HwReqChk" /v "HwReqChkVars" /t REG_MULTI_SZ /d "SQ_SecureBootCapable=TRUE\0SQ_SecureBootEnabled=TRUE\0SQ_TpmVersion=2\0SQ_RamMB=8192" /f 2>&1 | Write-Log
        reg add "HKLM\xNTUSER\Software\Microsoft\PCHC" /v "UpgradeEligibility" /t REG_DWORD /d "1" /f 2>&1 | Write-Log

        reg unload HKLM\xDEFAULT 2>&1 | Write-Log
        reg unload HKLM\xNTUSER 2>&1 | Write-Log
        reg unload HKLM\xSYSTEM 2>&1 | Write-Log
        reg unload HKLM\xSOFTWARE 2>&1 | Write-Log

        Invoke-DismFailsafe {Dismount-WindowsImage -Path $bootMountDir -Save} {dism /unmount-image /mountdir:$bootMountDir /commit}
        Write-Host ("[OK] Omision de TPM exitosa") -ForegroundColor Green
        Write-Log -msg "Successfully modified boot.wim for TPM Bypass"
    }
    catch {
        Write-Log -msg "Failed to mount boot.wim: $_"
    }
    finally {
        $ProgressPreference = 'Continue'
        Remove-Item -Path $bootMountDir -Recurse -Force -ErrorAction SilentlyContinue 2>&1 | Write-Log
    }
}
else {
    Write-Log -msg "TPM Bypass cancelled"
}

if ($buildNumber -ge 22000) {
    if ($DoUserFoldersEnable) {
        Write-Host ("`n[INFO] Restaurando carpetas de usuario...") -ForegroundColor Cyan

        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /f 2>&1 | Write-Log

        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /v "HideIfEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /v "HideIfEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /v "HideIfEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /v "HideIfEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /v "HideIfEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /v "HideIfEnabled" /t REG_DWORD /d "0" /f 2>&1 | Write-Log

        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /v "HiddenByDefault" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /v "HiddenByDefault" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /v "HiddenByDefault" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /v "HiddenByDefault" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /v "HiddenByDefault" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /v "HiddenByDefault" /t REG_DWORD /d "0" /f 2>&1 | Write-Log
        
        Write-Host ("[OK] Carpetas de usuario restauradas") -ForegroundColor Green
        Write-Log -msg "User folders restored successfully"
    } else {
        Write-Log -msg "User folders restoration cancelled"
    }
}

Write-Host ("`n[INFO] Descargando Registro...") -ForegroundColor Cyan
Write-Log -msg "Unloading registry"
reg unload HKLM\zCOMPONENTS 2>&1 | Write-Log
reg unload HKLM\zDEFAULT 2>&1 | Write-Log
reg unload HKLM\zNTUSER 2>&1 | Write-Log
reg unload HKLM\zSOFTWARE 2>&1 | Write-Log
reg unload HKLM\zSYSTEM 2>&1 | Write-Log
Write-Host ("[OK] Exito") -ForegroundColor Green

# --- Integracion de drivers desde carpeta local (sin Internet) ---
if ($DoDriverIntegrate) {
    Write-Host ("`n[INFO] Integracion de drivers desde carpeta local...") -ForegroundColor Cyan
    Write-Host ("  Selecciona la carpeta que contiene los drivers (con subcarpetas si es necesario).") -ForegroundColor DarkGray
    Write-Log -msg "Starting local driver integration"
    
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Selecciona la carpeta que contiene los drivers a integrar (p.ej., Intel RST/VMD)"
    $folderBrowser.ShowNewFolderButton = $false
    $dialogResult = $folderBrowser.ShowDialog()
    
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $driverSourcePath = $folderBrowser.SelectedPath
        Write-Host "  Carpeta seleccionada: $driverSourcePath" -ForegroundColor Green
        Write-Log -msg "Driver source path selected: $driverSourcePath"
        
        if (-not (Test-Path $driverSourcePath)) {
            Write-Host "  Error: La carpeta seleccionada no es valida." -ForegroundColor Red
            Write-Log -msg "Driver folder not found: $driverSourcePath"
        } else {
            try {
                Write-Host "  - Agregando drivers a install.wim..." -ForegroundColor DarkGray
                Invoke-DismFailsafe {Add-WindowsDriver -Path $installMountDir -Driver $driverSourcePath -Recurse -ForceUnsigned} {dism /image:$installMountDir /Add-Driver /driver:$driverSourcePath /recurse /ForceUnsigned}
                Write-Log -msg "Drivers added to install.wim"
                
                Write-Host "  - Agregando drivers a boot.wim..." -ForegroundColor DarkGray
                $bootWimPath = Join-Path $destinationPath "sources\boot.wim"
                $bootMountDir = "$env:SystemDrive\WIDTemporal\mountdir\bootWIM"
                New-Item -ItemType Directory -Path $bootMountDir -Force 2>&1 | Write-Log
                
                Write-Host "    Montando boot.wim..." -ForegroundColor DarkGray
                Invoke-DismFailsafe {Mount-WindowsImage -ImagePath $bootWimPath -Index 2 -Path $bootMountDir} {dism /mount-image /imagefile:$bootWimPath /index:2 /mountdir:$bootMountDir}
                Write-Host "    Agregando drivers..." -ForegroundColor DarkGray
                Invoke-DismFailsafe {Add-WindowsDriver -Path $bootMountDir -Driver $driverSourcePath -Recurse -ForceUnsigned} {dism /image:$bootMountDir /Add-Driver /driver:$driverSourcePath /recurse /ForceUnsigned}
                Write-Host "    Desmontando y guardando..." -ForegroundColor DarkGray
                Invoke-DismFailsafe {Dismount-WindowsImage -Path $bootMountDir -Save} {dism /unmount-image /mountdir:$bootMountDir /commit}
                
                Write-Log -msg "Drivers added to boot.wim"
                Write-Host ("[OK] Integracion de drivers completada") -ForegroundColor Green
                Write-Log -msg "Driver integration completed"
            }
            catch {
                Write-Host "  Error durante la integracion de drivers: $_" -ForegroundColor Red
                Write-Log -msg "Driver integration failed: $_"
            }
            finally {
                Remove-Item -Path $bootMountDir -Recurse -Force -ErrorAction SilentlyContinue 2>&1 | Write-Log
            }
        }
    } else {
        Write-Host "  No se selecciono ninguna carpeta. Se omite la integracion de drivers." -ForegroundColor Yellow
        Write-Log -msg "Driver integration cancelled by user"
    }
} else {
    Write-Log -msg "Driver integration skipped"
}
# --- Fin de integracion de drivers ---

Write-Host ("`n[INFO] Limpiando imagen...") -ForegroundColor Cyan
Write-Log -msg "Cleaning up image"
Invoke-DismFailsafe {Repair-WindowsImage -Path $installMountDir -StartComponentCleanup -ResetBase} {dism /image:$installMountDir /Cleanup-Image /StartComponentCleanup /ResetBase}

Write-Host ("`n[INFO] Desmontando y exportando imagen...") -ForegroundColor Cyan
Write-Log -msg "Unmounting image"
try {
    Write-Host "  Desmontando imagen, por favor espere..." -ForegroundColor DarkGray
    Invoke-DismFailsafe {Dismount-WindowsImage -Path $installMountDir -Save} {dism /unmount-image /mountdir:$installMountDir /commit}
    Write-Host "  [OK] Imagen desmontada correctamente" -ForegroundColor Green
    Write-Log -msg "Image unmounted successfully"
}
catch {
    Write-Host "`n`nError al desmontar la imagen. Revisa los logs." -ForegroundColor Red
    Write-Host "Cierra todas las carpetas abiertas en el directorio de montaje y ejecuta:"
    Write-Host "Dismount-WindowsImage -Path $installMountDir -Discard" -ForegroundColor Yellow
    Write-Log -msg "Failed to unmount image: $_"
    Pause
    Exit
}

Write-Log -msg "Exporting image"
$tempWimPath = "$destinationPath\sources\install_temp.wim"
$exportSuccess = $false

if ($DoESDConvert) {
    Write-Host ("`n[INFO] Comprimiendo imagen a ESD...") -ForegroundColor Cyan
    Write-Log -msg "Compressing image to esd"
    try {        
        Write-Host "  Comprimiendo (puede tardar varios minutos)..." -ForegroundColor DarkGray
        $process = Start-Process -FilePath "dism.exe" -ArgumentList "/Export-Image /SourceImageFile:`"$destinationPath\sources\install.wim`" /SourceIndex:$sourceIndex /DestinationImageFile:`"$tempWimPath`" /Compress:Recovery /CheckIntegrity" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0 -and (Test-Path $tempWimPath)) {
            $exportSuccess = $true
            Write-Host ("[OK] Compresion completada") -ForegroundColor Green
            Write-Log -msg "Compression completed"
        } else {
            Write-Host "La compresion fallo con codigo: $($process.ExitCode)" -ForegroundColor Red
            Write-Log -msg "Compression failed with exit code: $($process.ExitCode)"
        }
    } catch {
        Write-Host "Error en compresion: $_" -ForegroundColor Red
        Write-Log -msg "Compression failed with error: $_"
    }
}
else {
    Write-Host ("`n[INFO] Exportando imagen a WIM...") -ForegroundColor Cyan
    Write-Log -msg "Exporting image to wim"
    try {
        Write-Host "  Exportando, puede tardar varios minutos..." -ForegroundColor DarkGray
        Invoke-DismFailsafe {Export-WindowsImage -SourceImagePath "$destinationPath\sources\install.wim" -SourceIndex $sourceIndex -DestinationImagePath $tempWimPath -CompressionType Maximum -CheckIntegrity} {dism /Export-Image /SourceImageFile:$destinationPath\sources\install.wim /SourceIndex:$sourceIndex /DestinationImageFile:$tempWimPath /compress:max}
        if (Test-Path $tempWimPath) {
            $exportSuccess = $true
            Write-Host ("[OK] Exportacion completada exitosamente") -ForegroundColor Green
            Write-Log -msg "Export completed successfully"
        } else {
            Write-Host "Error: No se encontro el archivo WIM temporal" -ForegroundColor Red
            Write-Log -msg "Export failed - temp WIM not found"
        }
    } catch {
        Write-Host "Error en exportacion: $_" -ForegroundColor Red
        Write-Log -msg "Export failed with error: $_"
    }
}

if ($exportSuccess) {
    Remove-Item -Path "$destinationPath\sources\install.wim" -Force
    Move-Item -Path $tempWimPath -Destination "$destinationPath\sources\install.wim" -Force
   
    if (-not (Test-Path "$destinationPath\sources\install.wim")) {
        Write-Host "Error: No se pudo crear el archivo WIM. Revisa los logs." -ForegroundColor Red
        Write-Log -msg "Final install.wim missing"
        Pause
        Exit
    } else {
        Write-Log -msg "WIM file successfully replaced"
    }
} else {
    Write-Host "Error: No se pudo exportar el WIM modificado. Se conserva el original." -ForegroundColor Red
    Write-Log -msg "WIM export failed, original WIM file preserved"
    Pause
    Exit
}

try {
    $wimPath = Get-WindowsImage -ImagePath "$destinationPath\sources\install.wim" -ErrorAction Stop
    if ($wimPath) {
        Write-Host ("[OK] Validacion del archivo WIM exitosa: $($wimPath.Count) imagenes encontradas") -ForegroundColor Green
        Write-Log -msg "WIM validation passed: $($wimPath.Count) images found"
        [System.IO.File]::OpenWrite("$destinationPath\sources\install.wim").Close()
        Start-Sleep -Seconds 3
    } else {
        Write-Warning "La validacion no devolvio imagenes"
        Write-Log -msg "WIM validation warning: No images returned"
    }
} catch {
    Write-Host "Error: Fallo la validacion del WIM - $($_)" -ForegroundColor Red
    Write-Log -msg "WIM validation failed: $_"
}

Write-Log -msg "Checking required files"
if ($outputISO) {
    $ISOFileName = ($ISOFileName -replace '[<>:"/\\|?*\x00-\x1F\s]', '').Trim()
    $ISOFileName = [System.IO.Path]::GetFileNameWithoutExtension($outputISO)
} else {
    do {
        $ISOFileName = Read-Host -Prompt "`nIntroduce el nombre para el archivo ISO (sin extension)"
        $ISOFileName = ($ISOFileName -replace '[<>:"/\\|?*\x00-\x1F\s]', '').Trim()
        if ([string]::IsNullOrWhiteSpace($ISOFileName)) {
            Write-Warning "El nombre esta vacio o es invalido. Escribe un nombre valido."
        }
    } while ([string]::IsNullOrWhiteSpace($ISOFileName))
}
$ISOFile = Join-Path -Path $scriptDirectory -ChildPath "$ISOFileName.iso"
Write-Log -msg "ISO file name set to: $ISOFileName.iso"

if ($DoUseOscdimg) {
    if (-not (Test-Path -Path $Oscdimg)) {
        Write-Log -msg "Oscdimg.exe not found at '$Oscdimg'"
        Write-Host "`nOscdimg.exe no encontrado en '$Oscdimg'." -ForegroundColor Red
        Write-Host "`nIntentando descargar oscdimg.exe..." -ForegroundColor Cyan
        
        Test-InternetConnection | Out-Null

        $ADKfolder = "$scriptDirectory\ADKDownload"
        $CabFileName = "5d984200acbde182fd99cbfbe9bad133.cab"
        $ExtractedFileName = "fil720cc132fbb53f3bed2e525eb77bdbc1"

        New-Item -ItemType Directory -Path $OscdimgPath -Force 2>&1 | Write-Log
        New-Item -ItemType Directory -Path $ADKfolder -Force 2>&1 | Write-Log
        
        $RedirectResponse = Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2290227" -MaximumRedirection 0 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($RedirectResponse.StatusCode -eq 302) {
            $BaseURL = $RedirectResponse.Headers.Location.TrimEnd('/') + "/"
            $CabURL = "$BaseURL`Installers/$CabFileName"
            $CabFilePath = "$ADKfolder\$CabFileName"
        
            Write-Log -msg "Downloading CAB file from: $CabURL"
            Invoke-WebRequest -Uri $CabURL -OutFile $CabFilePath -UseBasicParsing
        
            Write-Log -msg "Extracting CAB file..."
            expand.exe -F:* $CabFilePath $ADKfolder 2>&1 | Write-Log
        
            $ExtractedFilePath = "$ADKfolder\$ExtractedFileName"
            $FinalFilePath = "$OscdimgPath\oscdimg.exe"
        
            if (Test-Path $ExtractedFilePath) {
                Move-Item -Path $ExtractedFilePath -Destination $FinalFilePath -Force 2>&1 | Write-Log
                Write-Host "Oscdimg.exe descargado exitosamente" -ForegroundColor Green
                Write-Log -msg "Oscdimg.exe successfully placed in: $OscdimgPath"
            }
            else {
                Write-Log -msg "Error: Extracted file not found!"
            }
        }
        else {
            Write-Host "Error: No se pudo descargar Oscdimg.exe" -ForegroundColor Red
            Write-Log -msg "Failed to resolve ADK download link. HTTP Status: $($RedirectResponse.StatusCode)"
            Remove-TempFiles
            Pause
            Exit
        }
    }

    Write-Host ("`n[INFO] Generando ISO...") -ForegroundColor Cyan
    Write-Log -msg "Generating ISO using OSCDIMG"
    try {
        $etfsbootPath = "$destinationPath\boot\etfsboot.com"
        $efisysPath = "$destinationPath\efi\Microsoft\boot\efisys.bin"
        $bootData = "2#p0,e,b`"$etfsbootPath`"#pEF,e,b`"$efisysPath`""
        Write-Log -msg "Boot data set: $bootData"
        
        $oscdimgArgs = @(
            "-bootdata:$bootData",
            "-m",
            "-o",
            "-h",
            "-u2",
            "-udfver102",
            "-l$ISOFileName",
            "`"$destinationPath`"",
            "`"$ISOFile`""
        )
        
        Write-Log -msg "OSCDIMG command: $Oscdimg $($oscdimgArgs -join ' ')"
        $oscdimgProcess = Start-Process -FilePath "$Oscdimg" -ArgumentList $oscdimgArgs -PassThru -Wait -NoNewWindow
        
        if ($oscdimgProcess.ExitCode -eq 0) {
            Write-Host ("[OK] Creacion del ISO exitosa") -ForegroundColor Green
            Write-Log -msg "ISO successfully created with exit code 0"
        } else {
            Write-Warning "La creacion del ISO termino con errores"
            Write-Log -msg "OSCDIMG exited with code: $($oscdimgProcess.ExitCode)"
        }
    }
    catch {
        Write-Log -msg "Failed to generate ISO with exit code: $_"
    }
}
else {
    Write-Host "`n[INFO] Preparando creacion del ISO..." -ForegroundColor Cyan
    Write-Log -msg "Preparing ISO creation"

    if (!('ISOWriter' -as [Type])) {
        Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;
        using System.Runtime.InteropServices.ComTypes;

        public class ISOWriter {
            [DllImport("shlwapi.dll", CharSet = CharSet.Unicode, ExactSpelling = true, PreserveSig = false)]
            private static extern void SHCreateStreamOnFileEx(string fileName, uint mode, uint attributes, bool create, IStream streamNull, out IStream stream);
            public static bool Create(string filePath, ref object imageStream, int blockSize, int totalBlocks) {IStream resultStream = (IStream)imageStream, imageFile; SHCreateStreamOnFileEx(filePath, 0x1001, 0x80, true, null, out imageFile); const int bufferSize = 1024; int remainingBlocks = totalBlocks;
                while (remainingBlocks > 0) { int blocksToWrite = Math.Min(remainingBlocks, bufferSize); resultStream.CopyTo(imageFile, blocksToWrite * blockSize, IntPtr.Zero, IntPtr.Zero); remainingBlocks -= blocksToWrite;}
                imageFile.Commit(0);
                return true;}
        }
'@
    }

    try {
        $comObjects = @()

        $bootStream = New-Object -ComObject ADODB.Stream -Property @{ Type = 1 }
        $comObjects += $bootStream
        $bootStream.Open()
        $bootStream.LoadFromFile("$destinationPath\efi\Microsoft\boot\efisys.bin")

        $bootOptions = New-Object -ComObject IMAPI2FS.BootOptions -Property @{
            PlatformId = 0xEF
            Manufacturer = "Microsoft"
            Emulation = 0
        }
        $comObjects += $bootOptions
        $bootOptions.AssignBootImage($bootStream)

        $FSImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage -Property @{
            FileSystemsToCreate = 4
            UDFRevision = 0x102
            FreeMediaBlocks = 0
            VolumeName = $ISOFileName
        }
        $comObjects += $FSImage
        
        Write-Log -msg "Creating ISO structure"
        $FSImage.Root.AddTree($destinationPath, $false)
        $FSImage.BootImageOptions = $bootOptions
        
        Write-Host "[INFO] Generando ISO..." -ForegroundColor Cyan
        Write-Log -msg "Generating ISO using ISOWriter"
        $resultImage = $FSImage.CreateResultImage()
        $comObjects += $resultImage

        [ISOWriter]::Create($ISOFile, [ref]$resultImage.ImageStream, $resultImage.BlockSize, $resultImage.TotalBlocks) | Out-Null
        
        if ((Get-Item $ISOFile).Length -eq ($resultImage.BlockSize * $resultImage.TotalBlocks)) {
            Write-Log -msg "ISO successfully created at: $ISOFile"
        }
    }
    catch {
        Write-Log -msg "ISO creation failed: $_" -Type Error
    }
    finally {
        foreach ($obj in $comObjects) {
            if ($obj) { 
                while ([Runtime.InteropServices.Marshal]::ReleaseComObject($obj) -gt 0) { }
            }
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        Write-Host "[OK] Creacion del ISO exitosa" -ForegroundColor Green
    }
}

if (Test-Path -Path $ISOFile) {
    try {
        $verifyMntResult = Mount-DiskImage -ImagePath "$ISOFile" -PassThru
        $verifyDrive = ($verifyMntResult | Get-Volume).DriveLetter
        $isoMountPoint = "${verifyDrive}:\"
        $reqFiles = @("sources\install.wim", "sources\boot.wim", "boot\bcd", "boot\boot.sdi", "bootmgr", "bootmgr.efi", "efi\microsoft\boot\efisys.bin")
        $missingFiles = $reqFiles | Where-Object { -not (Test-Path (Join-Path $isoMountPoint $_)) }

        Dismount-DiskImage -ImagePath "$ISOFile" 2>&1 | Write-Log

        if ($missingFiles) {
            Write-Host "`nError: El ISO creado no contiene archivos criticos" -ForegroundColor Red
            Write-Log -msg "ISO verification failed - missing files: $($missingFiles -join ', ')"
        }
        else {
            Write-Host "`nScript completado. El ISO se encuentra en: `"$scriptDirectory`"" -ForegroundColor Green
            Write-Log -msg "ISO verification successful"
        }
    }
    catch {
        Write-Warning "`nNo se pudo verificar la integridad del ISO"
        Write-Log -msg "Failed to verify ISO: $_"
    }
} else {
    Write-Host "`nError: No se creo el archivo ISO" -ForegroundColor Red
    Write-Log -msg "ISO file wasn't created"
}

Write-Log -msg "Removing temporary files"
try {
    Remove-TempFiles
}
catch {
    Write-Log -msg "Failed to remove temporary files: $_"
}
finally {
    Write-Log -msg "Script completed"
}

Write-Host
Pause
