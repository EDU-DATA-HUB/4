param(
  [Parameter(Mandatory = $true)]
  [string] $LogPath
)

function Write-LogLine {
  param([string] $Line)
  $color = 'Gray'
  if ($Line -match 'Server startup in') {
    $color = 'Green'
  } elseif ($Line -match '\b(ERROR|SEVERE|FATAL)\b|Exception') {
    $color = 'Red'
  } elseif ($Line -match '^\s+at |^Caused by:|^\s+\.\.\. \d+ more') {
    $color = 'DarkRed'
  } elseif ($Line -match '\b(WARN|WARNING)\b') {
    $color = 'Yellow'
  } elseif ($Line -match '\bINFO\b') {
    $color = 'Cyan'
  } elseif ($Line -match '\bDEBUG\b') {
    $color = 'DarkGray'
  }
  Write-Host $Line -ForegroundColor $color
}

Get-Content -LiteralPath $LogPath -Tail 80 -Wait -Encoding Default | ForEach-Object { Write-LogLine $_ }
