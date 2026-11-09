#Requires -Version 5.1
<#
.SYNOPSIS
    Run the top-level simulation against the Quartus netlist.

.DESCRIPTION
    Simulates simulation/questa/QuadrupleBuffer.vho -- the post-synthesis
    netlist including the altpll -- with the precompiled Altera libraries
    that ship with Questa FSE.

    This is a separate, slower flow from run_sim.ps1:
      * it needs a Quartus compile first (the .vho is a build product);
      * the netlist is gate-level, so it runs a short frame rather than the
        multi-frame RTL chain tests.
#>

$ErrorActionPreference = 'Stop'

$env:SALT_LICENSE_SERVER = 'C:\Users\12966\questa_lic.dat'

$questa = 'D:\altera\questa_fse\win64'
if (-not (Test-Path (Join-Path $questa 'vsim.exe'))) {
    throw "Questa not found at $questa"
}

$sim  = Split-Path -Parent $MyInvocation.MyCommand.Path
$fpga = Split-Path -Parent $sim
$vho  = Join-Path $fpga 'simulation\questa\QuadrupleBuffer.vho'
if (-not (Test-Path $vho)) {
    throw "Netlist not found: $vho`nCompile the Quartus project first (Processing > Start Compilation)."
}

$work = Join-Path $sim 'work_top'
New-Item -ItemType Directory -Force $work | Out-Null
Set-Location $work

Write-Host 'Compiling netlist and top testbench...'
& (Join-Path $questa 'vlib.exe') work | Out-Null
& (Join-Path $questa 'vcom.exe') -2008 -work work $vho (Join-Path $sim 'tb_top.vhd')
if ($LASTEXITCODE -ne 0) { throw 'vcom failed' }

$log = Join-Path $work 'tb_top.log'
& (Join-Path $questa 'vsim.exe') -t 1ps `
    -L altera -L cycloneive -L altera_mf -L altera_lnsim `
    -c -do "run 4 ms; quit -f" work.tb_top 2>&1 |
    Out-File -FilePath $log -Encoding utf8

if (Select-String -Path $log -Pattern 'TEST PASSED' -Quiet) {
    Write-Host 'PASS  tb_top'
} else {
    Write-Host "FAIL  tb_top  (see $log)"
    Get-Content $log -Tail 30 | ForEach-Object { Write-Host "      $_" }
    exit 1
}
