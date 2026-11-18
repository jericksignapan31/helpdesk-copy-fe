param(
  [Parameter(Position = 0)]
  [string]$RequestUri
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-StartupError {
  param([string]$Message)

  [System.Windows.Forms.MessageBox]::Show(
    $Message,
    'IT Help Desk Cleaner',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Error
  ) | Out-Null
}

try {
  $uri = [Uri]$RequestUri
  if (
    -not $uri.IsAbsoluteUri -or
    $uri.Scheme -ne 'ithelpdesk-cleaner' -or
    $uri.Host -ne 'run' -or
    $uri.AbsolutePath -ne '/' -and $uri.AbsolutePath -ne '' -or
    $uri.Query -ne '?profile=standard'
  ) {
    throw 'The request is not a supported cleanup profile.'
  }
} catch {
  Show-StartupError 'This request is not valid. Open Auto Cleaning from the IT Help Desk app.'
  exit 1
}

$windowsDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$recentDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Recent)
$userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
$userTempDirectory = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$profilePrefix = [IO.Path]::GetFullPath($userProfile).TrimEnd('\') + '\'

if (-not $userTempDirectory.StartsWith($profilePrefix, [StringComparison]::OrdinalIgnoreCase)) {
  $userTempDirectory = $null
}

$actions = @(
  [pscustomobject]@{
    Id = 'user-temp'
    Label = 'Current-user temporary files'
    Description = 'Removes items inside your Windows temporary folder.'
    DefaultChecked = $true
  }
  [pscustomobject]@{
    Id = 'windows-temp'
    Label = 'Windows temporary files'
    Description = 'Removes items inside Windows Temp; some items may require administrator access.'
    DefaultChecked = $false
  }
  [pscustomobject]@{
    Id = 'prefetch'
    Label = 'Prefetch cache'
    Description = 'Clears Windows Prefetch files; Windows may rebuild them.'
    DefaultChecked = $false
  }
  [pscustomobject]@{
    Id = 'recent'
    Label = 'Recent files list'
    Description = 'Clears shortcuts from your Windows Recent list, not the original files.'
    DefaultChecked = $true
  }
  [pscustomobject]@{
    Id = 'dns-cache'
    Label = 'DNS cache'
    Description = 'Flushes the local DNS resolver cache.'
    DefaultChecked = $false
  }
  [pscustomobject]@{
    Id = 'thumbnails'
    Label = 'Thumbnail cache'
    Description = 'Removes Windows thumbnail-cache database files.'
    DefaultChecked = $true
  }
  [pscustomobject]@{
    Id = 'windows-update'
    Label = 'Windows Update downloads'
    Description = 'Temporarily stops Windows Update and removes downloaded update files; access may be restricted.'
    DefaultChecked = $false
  }
  [pscustomobject]@{
    Id = 'recycle-bin'
    Label = 'Recycle Bin (permanent deletion)'
    Description = 'Permanently deletes Recycle Bin contents. This is never selected by default.'
    DefaultChecked = $false
  }
)

function Remove-AllowedDirectoryContents {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$Filter
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    return "Skipped: folder not found."
  }

  $root = Get-Item -LiteralPath $Path -Force
  if (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    return 'Skipped: cleanup folder is a link or mount point.'
  }

  if ($Filter) {
    $items = @(Get-ChildItem -LiteralPath $Path -Filter $Filter -Force -ErrorAction Stop)
  } else {
    $items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)
  }

  $removed = 0
  $failed = 0

  foreach ($item in $items) {
    try {
      Remove-AllowedItem -Path $item.FullName
      $removed++
    } catch {
      $failed++
    }
  }

  if ($failed -gt 0) {
    return "Partially completed: removed $removed item(s); could not remove $failed item(s), possibly because they are in use or access is restricted."
  }

  return "Completed: removed $removed item(s)."
}

function Remove-AllowedItem {
  param([Parameter(Mandatory = $true)][string]$Path)

  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
    return
  }

  if ($item.PSIsContainer) {
    $children = @(Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop)
    foreach ($child in $children) {
      Remove-AllowedItem -Path $child.FullName
    }
  }

  Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
}

function Invoke-AllowedCleanupAction {
  param([Parameter(Mandatory = $true)][string]$ActionId)

  switch ($ActionId) {
    'user-temp' {
      if (-not $userTempDirectory) {
        return 'Skipped: the configured temporary folder is outside your user profile.'
      }
      return Remove-AllowedDirectoryContents -Path $userTempDirectory
    }
    'windows-temp' {
      return Remove-AllowedDirectoryContents -Path (Join-Path $windowsDirectory 'Temp')
    }
    'prefetch' {
      return Remove-AllowedDirectoryContents -Path (Join-Path $windowsDirectory 'Prefetch')
    }
    'recent' {
      return Remove-AllowedDirectoryContents -Path $recentDirectory
    }
    'dns-cache' {
      Clear-DnsClientCache -ErrorAction Stop
      return 'Completed: DNS cache flushed.'
    }
    'thumbnails' {
      return Remove-AllowedDirectoryContents `
        -Path (Join-Path $localAppData 'Microsoft\Windows\Explorer') `
        -Filter 'thumbcache_*.db'
    }
    'windows-update' {
      $downloadDirectory = Join-Path $windowsDirectory 'SoftwareDistribution\Download'
      $service = Get-Service -Name 'wuauserv' -ErrorAction Stop
      $wasRunning = $service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running

      try {
        if ($wasRunning) {
          Stop-Service -Name 'wuauserv' -Force -ErrorAction Stop
          $service.WaitForStatus(
            [System.ServiceProcess.ServiceControllerStatus]::Stopped,
            [TimeSpan]::FromSeconds(30)
          )
        }

        return Remove-AllowedDirectoryContents -Path $downloadDirectory
      } finally {
        if ($wasRunning) {
          Start-Service -Name 'wuauserv' -ErrorAction Stop
        }
      }
    }
    'recycle-bin' {
      Clear-RecycleBin -Force -ErrorAction Stop
      return 'Completed: Recycle Bin contents permanently deleted.'
    }
    default {
      throw 'Unsupported cleanup action.'
    }
  }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'IT Help Desk - Auto Cleaning'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(620, 560)

$heading = New-Object System.Windows.Forms.Label
$heading.Location = New-Object System.Drawing.Point(16, 14)
$heading.Size = New-Object System.Drawing.Size(585, 42)
$heading.Text = 'Choose what to clean. Nothing runs until you confirm.'
$heading.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($heading)

$checks = @{}
$top = 62
foreach ($action in $actions) {
  $check = New-Object System.Windows.Forms.CheckBox
  $check.Location = New-Object System.Drawing.Point(20, $top)
  $check.Size = New-Object System.Drawing.Size(580, 48)
  $check.Text = "$($action.Label)`r`n$($action.Description)"
  $check.Checked = $action.DefaultChecked
  $check.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $check.AutoSize = $false
  $form.Controls.Add($check)
  $checks[$action.Id] = $check
  $top += 52
}

$warning = New-Object System.Windows.Forms.Label
$warning.Location = New-Object System.Drawing.Point(18, 482)
$warning.Size = New-Object System.Drawing.Size(585, 34)
$warning.Text = 'Recycle Bin cleanup permanently deletes files and requires a separate confirmation.'
$warning.ForeColor = [System.Drawing.Color]::DarkRed
$warning.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($warning)

$runButton = New-Object System.Windows.Forms.Button
$runButton.Location = New-Object System.Drawing.Point(348, 520)
$runButton.Size = New-Object System.Drawing.Size(132, 28)
$runButton.Text = 'Review and clean'
$form.Controls.Add($runButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(488, 520)
$cancelButton.Size = New-Object System.Drawing.Size(112, 28)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelButton)
$form.CancelButton = $cancelButton

$runButton.Add_Click({
  $selectedActions = @($actions | Where-Object { $checks[$_.Id].Checked })
  if ($selectedActions.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
      $form,
      'Select at least one cleanup action, or cancel.',
      'No actions selected',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    return
  }

  $summary = ($selectedActions | ForEach-Object { "- $($_.Label)" }) -join "`r`n"
  $confirmation = [System.Windows.Forms.MessageBox]::Show(
    $form,
    "The selected actions will run on this computer as your Windows user:`r`n`r`n$summary`r`n`r`nContinue?",
    'Confirm local cleanup',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Warning,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button2
  )

  if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) {
    return
  }

  if ($checks['recycle-bin'].Checked) {
    $recycleConfirmation = [System.Windows.Forms.MessageBox]::Show(
      $form,
      'This permanently deletes every item currently in the Recycle Bin. This cannot be undone. Continue with permanent deletion?',
      'Confirm permanent deletion',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Stop,
      [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )

    if ($recycleConfirmation -ne [System.Windows.Forms.DialogResult]::Yes) {
      return
    }
  }

  $form.Hide()
  $results = foreach ($action in $selectedActions) {
    try {
      $detail = Invoke-AllowedCleanupAction -ActionId $action.Id
      "$($action.Label): $detail"
    } catch {
      "$($action.Label): Failed - $($_.Exception.Message)"
    }
  }

  [System.Windows.Forms.MessageBox]::Show(
    ($results -join "`r`n`r`n"),
    'Auto Cleaning results',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
  ) | Out-Null
  $form.Close()
})

[void]$form.ShowDialog()
$form.Dispose()
