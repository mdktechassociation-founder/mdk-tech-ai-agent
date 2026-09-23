# Run inside the dedicated Windows guest as Administrator.
# -Install writes the guest bridge and registers it at guest boot.
# -Run starts the authenticated command bridge.
[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Run,
    [string]$Token = ''
)

$ErrorActionPreference = 'Stop'
$Root = Join-Path $env:ProgramData 'MDK Agent'
$InstalledScript = Join-Path $Root 'GuestAgent.ps1'
$TokenPath = Join-Path $Root 'guest-token.txt'
$TaskName = 'MDK Agent Guest Bridge'
$Port = 8765

function Send-Json($Context, $Payload, [int]$StatusCode = 200) {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Compress -Depth 8))
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = 'application/json'
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.Close()
}

function Get-GuestToken {
    if (-not (Test-Path $TokenPath)) { throw 'Guest token is not configured.' }
    return (Get-Content -LiteralPath $TokenPath -Raw).Trim()
}

if ($Install) {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Guest bridge installation must run as Administrator.'
    }
    if ([string]::IsNullOrWhiteSpace($Token)) {
        $bytes = New-Object byte[] 32
        [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
        $Token = [Convert]::ToBase64String($bytes)
    }
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    Set-Content -LiteralPath $TokenPath -Value $Token -Encoding ascii -NoNewline
    $acl = Get-Acl $TokenPath
    $acl.SetAccessRuleProtection($true, $false)
    $systemRule = New-Object Security.AccessControl.FileSystemAccessRule('SYSTEM', 'FullControl', 'Allow')
    $adminRule = New-Object Security.AccessControl.FileSystemAccessRule('Administrators', 'FullControl', 'Allow')
    $acl.SetAccessRule($systemRule)
    $acl.AddAccessRule($adminRule)
    Set-Acl -LiteralPath $TokenPath -AclObject $acl
    Copy-Item -LiteralPath $MyInvocation.MyCommand.Path -Destination $InstalledScript -Force

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$InstalledScript`" -Run"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Write-Output "Guest bridge installed. Copy this token into the host MDK_AGENT_GUEST_TOKEN secret: $Token"
    exit 0
}

if (-not $Run) {
    throw 'Use -Install or -Run.'
}

$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:$Port/")
$listener.Start()
$expectedToken = Get-GuestToken

while ($listener.IsListening) {
    $context = $listener.GetContext()
    try {
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.Url.AbsolutePath -eq '/health') {
            Send-Json $context @{ status = 'ok'; service = 'mdk-agent-guest'; execution = 'guest-only' }
            continue
        }
        $authorization = $context.Request.Headers['Authorization']
        if ($authorization -ne "Bearer $expectedToken") {
            Send-Json $context @{ error = 'unauthorized' } 401
            continue
        }
        if ($context.Request.HttpMethod -ne 'POST' -or $context.Request.Url.AbsolutePath -ne '/run') {
            Send-Json $context @{ error = 'not_found' } 404
            continue
        }
        $reader = New-Object IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $body = $reader.ReadToEnd()
        $request = $body | ConvertFrom-Json
        $command = [string]$request.command
        if ([string]::IsNullOrWhiteSpace($command) -or $command.Length -gt 20000) {
            Send-Json $context @{ error = 'command must be between 1 and 20000 characters' } 400
            continue
        }

        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = 'powershell.exe'
        $startInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded"
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        [void]$process.Start()
        if (-not $process.WaitForExit(120000)) {
            $process.Kill()
            Send-Json $context @{ exit_code = 124; stdout = ''; stderr = 'Guest command timed out after 120 seconds.' } 408
            continue
        }
        Send-Json $context @{ exit_code = $process.ExitCode; stdout = $process.StandardOutput.ReadToEnd(); stderr = $process.StandardError.ReadToEnd() }
    } catch {
        try { Send-Json $context @{ error = 'Guest command failed safely.' } 500 } catch { }
    }
}
