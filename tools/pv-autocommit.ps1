param(
  [string]$RepoPath = "C:\prompt-vault",
  [string]$CommitMessagePrefix = "auto: save prompts"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ToolsPath = Join-Path $RepoPath "tools"
$LogDir    = Join-Path $ToolsPath "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir ("pv-autocommit_{0}.log" -f (Get-Date -Format "yyyyMMdd"))

function Log([string]$msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
  Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

try {
  if (-not (Test-Path $RepoPath)) {
    throw "RepoPath not found: $RepoPath"
  }

  Set-Location $RepoPath

  $git = Get-Command git -ErrorAction Stop
  Log "git: $($git.Source)"

  git rev-parse --is-inside-work-tree *> $null
  if ($LASTEXITCODE -ne 0) { throw "Not a git repository: $RepoPath" }

  git update-index -q --refresh

  $porcelain = git status --porcelain
  if ([string]::IsNullOrWhiteSpace($porcelain)) {
    Log "No changes. Exit."
    exit 0
  }

  Log "Changes detected:"
  ($porcelain -split "`n" | Where-Object { $_.Trim() -ne "" }) | ForEach-Object { Log "  $_" }

  git add -A

  $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
  $msg = "{0} ({1})" -f $CommitMessagePrefix, $ts

  git commit -m $msg
  if ($LASTEXITCODE -ne 0) {
    Log "git commit returned non-zero. Possibly nothing staged. Exit."
    exit 0
  }

  Log "Committed: $msg"
  exit 0
}
catch {
  Log ("ERROR: " + $_.Exception.Message)
  exit 1
}
