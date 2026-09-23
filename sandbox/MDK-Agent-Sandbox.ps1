# MDK Agent isolated Windows guest lifecycle.
# This script intentionally exposes only fixed Hyper-V lifecycle actions. It does
# not execute arbitrary host commands on behalf of the model.
[CmdletBinding()]
param(
    [ValidateSet('status', 'create', 'start', 'stop', 'destroy')]
    [string]$Action = 'status',
    [string]$VmName = 'MDK-Agent-VM',
    [string]$IsoPath = '',
    [string]$ConfirmationPhrase = '',
    [string]$SandboxRoot = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$ExpectedRoot = Join-Path $env:LOCALAPPDATA 'MDK Agent\Sandbox'
if ([string]::IsNullOrWhiteSpace($SandboxRoot)) {
    $SandboxRoot = $ExpectedRoot
}

function Resolve-ManagedRoot([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $expected = [IO.Path]::GetFullPath($ExpectedRoot).TrimEnd('\')
    if ($full -ne $expected) {
        throw 'Sandbox root is fixed to the MDK Agent managed directory.'
    }
    return $full
}

$SandboxRoot = Resolve-ManagedRoot $SandboxRoot
$VmDisk = Join-Path $SandboxRoot 'MDK-Agent-VM.vhdx'
$RequiredPhrase = 'DESTROY MDK AGENT VM'

function Write-Result($Value) {
    if (-not $Quiet) {
        $Value | ConvertTo-Json -Compress
    }
}

function Is-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-HyperV {
    if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
        throw 'Hyper-V PowerShell tools are unavailable. Enable Hyper-V on Windows Pro/Enterprise first.'
    }
}

function Invoke-ElevatedIfNeeded {
    if ($Action -eq 'status' -or (Is-Administrator)) {
        return
    }

    $powershell = (Get-Command powershell.exe).Source
    $script = $script:PSCommandPath
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script,
        '-Action', $Action, '-VmName', $VmName,
        '-SandboxRoot', $SandboxRoot
    )
    if ($IsoPath) { $arguments += @('-IsoPath', $IsoPath) }
    if ($ConfirmationPhrase) { $arguments += @('-ConfirmationPhrase', $ConfirmationPhrase) }
    $process = Start-Process -FilePath $powershell -Verb RunAs -ArgumentList $arguments -Wait -PassThru
    exit $process.ExitCode
}

function Get-SandboxState {
    $managedData = Test-Path $SandboxRoot
    $vm = $null
    $ipAddresses = @()
    $hyperV = [bool](Get-Command Get-VM -ErrorAction SilentlyContinue)
    if ($hyperV) {
        try {
            $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
            if ($vm) {
                $ipAddresses = @(Get-VMNetworkAdapter -VMName $VmName -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty IPAddresses |
                    Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' })
            }
        } catch {
            $vm = $null
        }
    }
    [ordered]@{
        mode = 'hyperv-isolated-guest'
        supported = $hyperV
        vm_name = $VmName
        vm_exists = [bool]$vm
        vm_state = if ($vm) { [string]$vm.State } else { 'NotCreated' }
        ip_addresses = @($ipAddresses)
        managed_data_exists = $managedData
        sandbox_root = $SandboxRoot
        host_control = 'lifecycle-only'
        guest_control = 'reserved-for-sandbox-agent'
        message = if ($hyperV) { 'Hyper-V sandbox lifecycle is available.' } else { 'Enable Hyper-V before creating the isolated guest.' }
    }
}

Invoke-ElevatedIfNeeded

if ($Action -eq 'status') {
    if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
        Write-Result (Get-SandboxState)
        if ($Quiet -and (Test-Path $SandboxRoot)) { exit 10 }
        exit 0
    }
    Write-Result (Get-SandboxState)
    if ($Quiet -and (Test-Path $SandboxRoot)) { exit 10 }
    exit 0
}

Assert-HyperV

switch ($Action) {
    'create' {
        if ([string]::IsNullOrWhiteSpace($IsoPath) -or -not (Test-Path $IsoPath -PathType Leaf)) {
            throw 'A valid Windows ISO path is required to create the guest.'
        }
        if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) {
            throw "The managed VM '$VmName' already exists."
        }
        New-Item -ItemType Directory -Path $SandboxRoot -Force | Out-Null
        New-VHD -Path $VmDisk -SizeBytes 64GB -Dynamic | Out-Null
        $switch = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue
        if ($switch) {
            New-VM -Name $VmName -MemoryStartupBytes 8GB -Generation 2 -VHDPath $VmDisk -SwitchName $switch.Name | Out-Null
        } else {
            New-VM -Name $VmName -MemoryStartupBytes 8GB -Generation 2 -VHDPath $VmDisk | Out-Null
        }
        Set-VMProcessor -VMName $VmName -Count 4
        Set-VM -Name $VmName -AutomaticStopAction Shutdown -AutomaticStartAction Nothing
        Set-VMFirmware -VMName $VmName -EnableSecureBoot On -SecureBootTemplate 'MicrosoftWindows'
        Add-VMDvdDrive -VMName $VmName -Path $IsoPath | Out-Null
        $dvd = Get-VMDvdDrive -VMName $VmName
        Set-VMFirmware -VMName $VmName -FirstBootDevice $dvd
        Write-Result (Get-SandboxState)
    }
    'start' {
        if (-not (Get-VM -Name $VmName -ErrorAction SilentlyContinue)) { throw 'The managed VM has not been created.' }
        Start-VM -Name $VmName | Out-Null
        Write-Result (Get-SandboxState)
    }
    'stop' {
        $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
        if ($vm -and $vm.State -ne 'Off') { Stop-VM -Name $VmName -TurnOff -Force | Out-Null }
        Write-Result (Get-SandboxState)
    }
    'destroy' {
        if ($ConfirmationPhrase -cne $RequiredPhrase) {
            throw "Destruction requires the exact confirmation phrase: $RequiredPhrase"
        }
        $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
        if ($vm) {
            if ($vm.State -ne 'Off') { Stop-VM -Name $VmName -TurnOff -Force | Out-Null }
            Remove-VM -Name $VmName -Force
        }
        if (Test-Path $SandboxRoot) { Remove-Item -LiteralPath $SandboxRoot -Recurse -Force }
        Write-Result ([ordered]@{ mode = 'hyperv-isolated-guest'; destroyed = $true; vm_name = $VmName })
    }
}
