# dev-setup

One-command setup for a new or reset development computer, following my
"SOP — New or Reset Development Computer Setup" (§2–§6).

Installs whatever is missing: OS updates, Chrome, Git, Python, VS Code and the
Microsoft Python extensions. Sets Git identity, runs a Python check and saves a
`computer-inventory-*.txt` report to the home folder. Anything already
installed is skipped, so running it again is safe. It never replaces system
Python and never touches repositories or secrets.

## Run it

**Kubuntu / macOS** (Konsole or Terminal):

```bash
curl -fsSL https://raw.githubusercontent.com/tunaflyby/dev-setup/main/setup.sh | bash
```

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/tunaflyby/dev-setup/main/setup.ps1 | iex
```

## Check only (changes nothing)

```bash
curl -fsSL https://raw.githubusercontent.com/tunaflyby/dev-setup/main/setup.sh | bash -s -- --check
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/tunaflyby/dev-setup/main/setup.ps1))) -Check
```

## Still done by hand afterwards

- Chrome profile sign-in and sync choices
- Dashlane extension sign-in
- GitHub (tunaflyby), ChatGPT, Claude, Notion, Drive, Dropbox sign-ins
- VS Code → Backup and Sync Settings
- Run `~/setup-check/hello.py` in VS Code
- Attach the inventory report to the computer's Notion Assets record
