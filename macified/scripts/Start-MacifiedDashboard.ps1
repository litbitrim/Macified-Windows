#Requires -Version 5.1
<#
    Minimal read-only dashboard server for the Macified status snapshot.

    Binds to 127.0.0.1 only, serves three static files and one JSON endpoint.
    It never writes files, starts applications or changes settings. Stop it
    with Ctrl+C.
#>
[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 5555
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot 'Macified.Dashboard.psm1') -Force

$script:ConfigPath = Join-Path $PSScriptRoot '..\config\macified.psd1'
$dashboardRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\dashboard'))

$assets = @{}
$contentTypes = @{
    '/index.html' = 'text/html; charset=utf-8'
    '/styles.css' = 'text/css; charset=utf-8'
    '/app.js'     = 'application/javascript; charset=utf-8'
}

foreach ($name in @('index.html', 'styles.css', 'app.js')) {
    $file = Join-Path $dashboardRoot $name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Write-Host "Dashboard-Datei fehlt: $file" -ForegroundColor Red
        exit 2
    }

    $assets["/$name"] = @{
        Bytes = [System.IO.File]::ReadAllBytes($file)
        Type  = $contentTypes["/$name"]
    }
}

$script:StatusJson = $null
$script:StatusUntil = [datetime]::MinValue

function Get-StatusJson {
    if ($null -eq $script:StatusJson -or (Get-Date) -ge $script:StatusUntil) {
        $snapshot = Get-MacifiedDashboardStatus -ConfigPath $script:ConfigPath
        $script:StatusJson = ($snapshot | ConvertTo-Json -Depth 10 -Compress)
        $script:StatusUntil = (Get-Date).AddSeconds(5)
    }

    return $script:StatusJson
}

function Send-Response {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$ContentType,
        [byte[]]$Body
    )

    if ($null -eq $Body) {
        $Body = New-Object byte[] 0
    }

    $reason = switch ($StatusCode) {
        200 { 'OK' }
        400 { 'Bad Request' }
        404 { 'Not Found' }
        405 { 'Method Not Allowed' }
        default { 'Internal Server Error' }
    }

    $headers = @(
        "HTTP/1.1 $StatusCode $reason"
        "Date: $((Get-Date).ToUniversalTime().ToString('r'))"
        "Content-Type: $ContentType"
        "Content-Length: $($Body.Length)"
        'Cache-Control: no-store'
        'X-Content-Type-Options: nosniff'
        'X-Frame-Options: DENY'
        'Referrer-Policy: no-referrer'
        'Cross-Origin-Opener-Policy: same-origin'
        'Cross-Origin-Resource-Policy: same-origin'
        'Permissions-Policy: camera=(), microphone=(), geolocation=()'
        "Content-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    )

    $headBytes = [System.Text.Encoding]::ASCII.GetBytes((($headers -join "`r`n") + "`r`n`r`n"))
    $Stream.Write($headBytes, 0, $headBytes.Length)
    if ($Body.Length -gt 0) {
        $Stream.Write($Body, 0, $Body.Length)
    }
    $Stream.Flush()
}

function Send-TextResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$Text
    )

    Send-Response -Stream $Stream -StatusCode $StatusCode -ContentType 'text/plain; charset=utf-8' `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($Text))
}

# Warm the first snapshot so the initial browser request is not the slowest.
$script:StatusJson = (Get-MacifiedDashboardStatus -ConfigPath $script:ConfigPath) | ConvertTo-Json -Depth 10 -Compress
$script:StatusUntil = (Get-Date).AddSeconds(5)

$listener = $null
try {
    $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback), $Port

    try {
        $listener.Start()
    }
    catch [System.Net.Sockets.SocketException] {
        Write-Host "Port $Port ist belegt. Mit -Port einen anderen Wert wählen." -ForegroundColor Red
        exit 2
    }

    Write-Host ''
    Write-Host 'Macified Status Dashboard' -ForegroundColor Cyan
    Write-Host "URL:      http://127.0.0.1:$Port/"
    Write-Host 'Bindung:  127.0.0.1 (nur dieser PC)'
    Write-Host 'Modus:    read-only, keine Schreibzugriffe'
    Write-Host 'Beenden:  Ctrl+C'
    Write-Host ''

    while ($true) {
        $client = $listener.AcceptTcpClient()

        try {
            $client.ReceiveTimeout = 5000
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $stream.WriteTimeout = 5000

            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
            $requestLine = $reader.ReadLine()

            if ([string]::IsNullOrWhiteSpace($requestLine)) {
                continue
            }

            $parts = $requestLine -split ' '
            if ($parts.Count -lt 2) {
                Send-TextResponse -Stream $stream -StatusCode 400 -Text "Ungültige Anfrage.`n"
                continue
            }

            $method = $parts[0].ToUpperInvariant()
            $path = ($parts[1] -split '\?')[0]

            if ($method -ne 'GET') {
                Send-TextResponse -Stream $stream -StatusCode 405 -Text "Nur GET wird unterstützt.`n"
                continue
            }

            if ($path -eq '/api/status') {
                $json = Get-StatusJson
                Send-Response -Stream $stream -StatusCode 200 -ContentType 'application/json; charset=utf-8' `
                    -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
                continue
            }

            $route = if ($path -eq '/' -or $path -eq '/index.html') { '/index.html' } else { $path }

            if ($assets.ContainsKey($route)) {
                $asset = $assets[$route]
                Send-Response -Stream $stream -StatusCode 200 -ContentType $asset.Type -Body $asset.Bytes
                continue
            }

            Send-TextResponse -Stream $stream -StatusCode 404 -Text "Nicht gefunden.`n"
        }
        catch [System.IO.IOException] {
            # Client disconnected or timed out; the next loop iteration continues.
        }
        catch {
            Write-Host "Anfrage fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
        finally {
            if ($null -ne $client) {
                $client.Close()
            }
        }
    }
}
finally {
    if ($null -ne $listener) {
        $listener.Stop()
    }
}
