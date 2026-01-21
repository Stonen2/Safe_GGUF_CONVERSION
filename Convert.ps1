# Safe GGUF Conversion Script (Windows PowerShell 5.1 compatible)

$PythonExe = 'C:\Users\ISAdmin\Desktop\LLM\venv\Scripts\python.exe'
$ModelPath = 'E:\LLM'
$OutType   = 'bf16'
$MaxRamGB  = 40
$TempDir   = 'E:\fast_temp'
$Poll      = 10

if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

$env:TEMP = $TempDir
$env:TMP  = $TempDir

$argsList = @(
    'convert_hf_to_gguf.py'
    $ModelPath
    '--outtype'
    $OutType
    '--outfile'
    'E:\gguf\deepseek.gguf'
    '--use-temp-file'
)

Write-Host Starting GGUF conversion
Write-Host RAM watchdog: $MaxRamGB GB

$proc = Start-Process `
    -FilePath $PythonExe `
    -ArgumentList $argsList `
    -PassThru `
    -WindowStyle Hidden

if (-not $proc) {
    Write-Host Failed to start process
    exit 1
}

# Set priority AFTER start (PS 5.1 compatible)
try {
    $proc.PriorityClass = 'BelowNormal'
} catch {}

Write-Host Process started. PID: $proc.Id
Write-Host Monitoring memory usage

while (-not $proc.HasExited) {

    $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue

    if ($p) {
        $ram = [Math]::Round($p.WorkingSet64 / 1GB, 2)
        Write-Host RAM usage: $ram GB

        if ($ram -gt $MaxRamGB) {
            Write-Host RAM limit exceeded. Killing process.
            Stop-Process -Id $proc.Id -Force
            break
        }
    }

    Start-Sleep $Poll
}

Write-Host Process exited
