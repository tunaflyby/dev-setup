# =====================================================================
#  Tuan's dev computer setup — Windows
#  Follows "SOP — New or Reset Development Computer Setup" §2–§6.
#
#  Run it:      powershell -ExecutionPolicy Bypass -File setup.ps1
#  Check only:  powershell -ExecutionPolicy Bypass -File setup.ps1 -Check
#
#  Safe to run again: anything already installed is skipped.
# =====================================================================
param([switch]$Check)

$GitName    = "Tuan Le"
$Extensions = @("ms-python.python", "ms-python.vscode-pylance", "ms-python.debugpy")
$Failures   = @()

function Head($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  [ok]   $t" -ForegroundColor Green }
function Todo($t) { Write-Host "  [todo] $t" -ForegroundColor Yellow }
function Fail($t) { Write-Host "  [FAIL] $t" -ForegroundColor Red; $script:Failures += $t }
function Has($c)  { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function RefreshPath {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path", "User")
}
function WingetInstall($id, $label) {
  winget install --id $id --exact --source winget --accept-source-agreements --accept-package-agreements
  RefreshPath
  if ($LASTEXITCODE -eq 0) { Ok "$label installed" } else { Fail "$label install (winget $id)" }
}

Write-Host "Tuan's setup launcher — Windows — $(if ($Check) {'CHECK ONLY'} else {'INSTALL MISSING'})"

if (-not (Has winget)) {
  Write-Host "WinGet is missing. Install/update 'App Installer' from Microsoft Store, then re-run." -ForegroundColor Red
  exit 1
}

# ---------- §2 OS + app updates ----------
Head "§2 Updates"
if ($Check) { Todo "Skipped in -Check mode" } else {
  Start-Process "ms-settings:windowsupdate"
  Todo "Windows Update opened — click 'Check for updates' and restart when asked."
  winget upgrade
  $a = Read-Host "  Install all app updates listed above? [y/N]"
  if ($a -match '^[Yy]') { winget upgrade --all --accept-source-agreements --accept-package-agreements }
}

# ---------- §2 Chrome ----------
Head "§2 Chrome"
$chromePaths = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                 "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                 "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
if ($chromePaths | Where-Object { Test-Path $_ }) { Ok "Chrome installed" }
elseif ($Check) { Todo "Chrome missing" }
else { WingetInstall "Google.Chrome" "Chrome" }

# ---------- §3 Git ----------
Head "§3 Git"
if (Has git) { Ok (git --version) }
elseif ($Check) { Todo "Git missing" }
else { WingetInstall "Git.Git" "Git" }

# ---------- §3 Python 3.13 (via Python install manager) ----------
Head "§3 Python 3.13"
function Py313 { if (Has py) { & py -3.13 --version 2>$null; return ($LASTEXITCODE -eq 0) } ; return $false }
if (Py313) { Ok "Python 3.13 present" }
elseif ($Check) { Todo "Python 3.13 missing" }
else {
  if (-not (Has pymanager)) { WingetInstall "Python.PythonInstallManager" "Python install manager" }
  if (Has pymanager) { pymanager install 3.13; RefreshPath }
  if (-not (Py313)) {
    Todo "Install manager route failed; trying the standard Python 3.13 package"
    WingetInstall "Python.Python.3.13" "Python 3.13"
  }
  if (Py313) { Ok (py -3.13 --version) } else { Fail "Python 3.13 — close and reopen PowerShell, then re-run" }
}

# ---------- §3 VS Code + extensions ----------
Head "§3 VS Code"
if (Has code) { Ok "VS Code $((code --version)[0])" }
elseif ($Check) { Todo "VS Code missing" }
else { WingetInstall "Microsoft.VisualStudioCode" "VS Code" }

if (Has code) {
  $installed = code --list-extensions
  foreach ($e in $Extensions) {
    if ($installed -contains $e) { Ok "extension $e" }
    elseif ($Check) { Todo "extension $e missing" }
    else { code --install-extension $e --force | Out-Null; if ($LASTEXITCODE -eq 0) { Ok "extension $e installed" } else { Fail "extension $e" } }
  }
}

# ---------- §4 Git identity ----------
Head "§4 Git identity"
if (Has git) {
  if (-not $Check) {
    git config --global user.name $GitName
    git config --global init.defaultBranch main
    if (-not (git config --global --get user.email)) {
      Write-Host "  GitHub -> Settings -> Emails: copy your verified or noreply address."
      $email = Read-Host "  Paste GitHub email (Enter to skip)"
      if ($email) { git config --global user.email $email }
    }
  }
  foreach ($k in "user.name", "user.email", "init.defaultBranch") {
    $v = git config --global --get $k
    if ($v) { Ok "$k = $v" } else { Todo "$k not set" }
  }
}

# ---------- §5 Python check ----------
Head "§5 Python check"
if (Py313) {
  $out = py -3.13 -c "print(""Tuan's Python setup is working."")"
  if ($LASTEXITCODE -eq 0) { Ok $out } else { Fail "Python test" }
  if (-not $Check) {
    $dir = Join-Path $env:USERPROFILE "setup-check"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $hello = Join-Path $dir "hello.py"
    if (-not (Test-Path $hello)) { 'print("Tuan''s Python setup is working.")' | Out-File $hello -Encoding utf8 }
    Todo "Open $dir in VS Code -> Python: Select Interpreter -> Run hello.py"
  }
}

# ---------- §6 Inventory report ----------
if (-not $Check) {
  Head "§6 Computer inventory report"
  $report = Join-Path $env:USERPROFILE ("computer-inventory-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")
  & {
    "COMPUTER SETUP SNAPSHOT"; Get-Date -Format o; "Hostname: $env:COMPUTERNAME"
    "=== OS ===";       Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture | Format-List | Out-String
    "=== Computer ==="; Get-CimInstance Win32_ComputerSystem  | Select-Object Manufacturer, Model, TotalPhysicalMemory | Format-List | Out-String
    "=== BIOS / serial ==="; Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion, SerialNumber | Format-List | Out-String
    "=== CPU ===";      Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors | Format-List | Out-String
    "=== Physical drives ==="; Get-CimInstance Win32_DiskDrive | Select-Object Model, Size, InterfaceType | Format-Table -AutoSize | Out-String
    "=== Git ===";      if (Has git) { git --version } else { "Git not found" }
    "=== Python 3.13 ==="; if (Has py) { py -3.13 --version; py -3.13 -m pip --version } else { "py command not found" }
    "=== VS Code ===";  if (Has code) { code --version } else { "code command not found" }
    "=== Manual checks ==="
    "Setup status: TO CONFIRM"
    "Unresolved issues: $(if ($Failures) { $Failures -join '; ' } else { 'None found by script' })"
    "Chrome / Dashlane / settings sync / Python sample / backup restore: TO CONFIRM"
  } 2>&1 | Out-File -FilePath $report -Encoding utf8
  Ok "Saved report: $report"
}

# ---------- Summary ----------
Head "Summary"
if ($Failures) { $Failures | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }; "  Fix the items above and run again." }
else { Ok "Everything the script can do is done." }

@"

  Still yours to do by hand (sign-ins can't be scripted):
  [ ] Chrome: sign into your profile, review sync choices
  [ ] Install Dashlane extension -> sign in -> test a fill   https://www.dashlane.com/download
  [ ] In Chrome sign into GitHub (tunaflyby), ChatGPT, Claude, Notion, Drive, Dropbox
  [ ] VS Code -> Accounts -> Backup and Sync Settings -> sign in with GitHub tunaflyby
  [ ] Run setup-check\hello.py in VS Code (Select Interpreter first)
  [ ] Attach the computer-inventory-*.txt report to this computer's Notion Assets record
"@
