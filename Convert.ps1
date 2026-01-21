# ============================================================
# Safe GGUF Conversion Script (Windows)
# Prevents system crashes by hard-limiting RAM
# ============================================================

# ---------------- CONFIG ----------------
$PythonExe       = "C:\Users\ISAdmin\Desktop\LLM\venv\Scripts\python.exe"
$ModelPath       = "E:\LLM"   # path to HF model directory
$OutType         = "bf16"
$MemoryLimitGB   = 40        # HARD RAM LIMIT
$CpuLimitPercent = 80        # CPU throttle
$TempDir         = "E:\fast_temp"  # MUST exist, ideally NVMe
$PollSeconds     = 10
# ----------------------------------------

# Ensure temp directory exists
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

# Environment tuning (reduces fragmentation & RAM spikes)
$env:TEMP = $TempDir
$env:TMP  = $TempDir
$env:PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True"
$env:MALLOC_TRIM_THRESHOLD_ = "524288"

# Build arguments
$Args = "convert_hf_to_gguf.py `"$ModelPath`" --outtype $OutType --outfile E:\gguf\deepseek.gguf --use-temp-file"

# ---------------- JOB OBJECT SETUP ----------------
Add-Type -AssemblyName System.Runtime.InteropServices

$job  = New-Object System.Diagnostics.Job
$info = New-Object System.Diagnostics.JobObjectExtendedLimitInformation

# Enable hard memory cap + kill-on-close
$info.BasicLimitInformation.LimitFlags =
    [System.Diagnostics.JobObjectLimitFlags]::ProcessMemory `
    -bor [System.Diagnostics.JobObjectLimitFlags]::KillOnJobClose `
    -bor [System.Diagnostics.JobObjectLimitFlags]::CpuRateControl

# Memory cap (bytes)
$info.ProcessMemoryLimit = $MemoryLimitGB * 1GB

# CPU throttle
$info.CpuRateControlInformation.ControlFlags = 1
$info.CpuRateControlInformation.CpuRate =
    [int]($CpuLimitPercent * 100)   # 10000 = 100%

# Apply job limits
$job.SetExtendedLimitInformation($info)

# ---------------- START PROCESS ----------------
Write-Host "Starting GGUF conversion with:"
Write-Host "  RAM cap : $MemoryLimitGB GB"
Write-Host "  CPU cap : $CpuLimitPercent %"
Write-Host "  Temp dir: $TempDir"
Write-Host ""

$proc = Start-Process $PythonExe `
    -ArgumentList $Args `
    -PassThru `
    -Priority BelowNormal `
    -WindowStyle Hidden

# Attach to job object
$job.AddProcess($proc)

Write-Host "Process started (PID $($proc.Id))"
Write-Host "Monitoring memory usage..."

# ---------------- MONITOR LOOP ----------------
try {
    while (-not $proc.HasExited) {
        $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if ($p) {
            $ramGB = [Math]::Round($p.WorkingSet64 / 1GB, 2)
            Write-Host ("[{0}] RAM: {1} GB" -f (Get-Date -Format HH:mm:ss), $ramGB)
        }
        Start-Sleep $PollSeconds
    }
}
finally {
    Write-Host ""
    Write-Host "Process exited with code $($proc.ExitCode)"
}

# ============================================================
# Notes:
# - If RAM exceeds limit → process is terminated safely
# - Convert to f16 ONLY; quantize later using llama.cpp
# - Increase MemoryLimitGB cautiously for 13B+ models
# ============================================================
