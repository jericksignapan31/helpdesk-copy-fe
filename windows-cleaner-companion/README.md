# IT Help Desk Windows Cleaner Companion

This local PowerShell companion is separate from the NestJS backend. It only
accepts the fixed `ithelpdesk-cleaner://run?profile=standard` protocol request.
The request contains no script path, shell command, or action list.

The companion presents a local action checklist before doing anything. Only
current-user temporary files, the Recent list, and thumbnail cache are selected
by default. Other actions are opt-in. The Recycle Bin is never selected by
default and requires a second confirmation because its contents are permanently
deleted.

Cleanup runs with the current Windows user's permissions. The companion does
not request elevation; Windows-protected items may fail and are reported. It
does not contact the backend and does not execute the legacy `.bat` files.

## Install for the current Windows user

1. Keep this folder in a stable local location.
2. Open PowerShell in this folder and run:

   ```powershell
   .\Install-Companion.ps1
   ```

3. Restart the browser. The browser/Windows may ask permission to open the
   external companion when the Auto Cleaning button is clicked.

The installer registers the protocol under the current user's registry hive;
administrator access is not required.

If your organization's PowerShell policy blocks unsigned local scripts, ask
your IT administrator to review and sign/package the companion. Do not weaken
the machine-wide execution policy.

## Uninstall

Run `.\Uninstall-Companion.ps1` from this folder. This removes only the
`ithelpdesk-cleaner` protocol registration for the current Windows user.
