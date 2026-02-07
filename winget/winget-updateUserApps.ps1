<#
.SYNOPSIS
    Updates user-level applications when run as currently logged in user.
.DESCRIPTION
    Runs in the current user context to update user-level applications. Packages requiring administrative permissions will prompt for UAC approval.
#>

$ErrorActionPreference = "Stop"

$cmd = Get-Command winget -ErrorAction SilentlyContinue
if (-not $cmd) { throw "winget not found in user context. Run the SYSTEM automation first." }

& $cmd.Source upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --silent
