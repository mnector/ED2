$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='Setup'; $form.StartPosition='CenterScreen'; $form.ClientSize=New-Object Drawing.Size(520,275)
$form.FormBorderStyle='FixedDialog'; $form.MaximizeBox=$false
$label=New-Object Windows.Forms.Label; $label.Location=New-Object Drawing.Point(20,20); $label.Size=New-Object Drawing.Size(220,22); $label.Text='Game executable'; $form.Controls.Add($label)
$path=New-Object Windows.Forms.TextBox; $path.Location=New-Object Drawing.Point(20,43); $path.Size=New-Object Drawing.Size(380,25); $path.ReadOnly=$true; $form.Controls.Add($path)
$browse=New-Object Windows.Forms.Button; $browse.Location=New-Object Drawing.Point(410,41); $browse.Size=New-Object Drawing.Size(90,29); $browse.Text='Browse...'; $form.Controls.Add($browse)
$dllLabel=New-Object Windows.Forms.Label; $dllLabel.Location=New-Object Drawing.Point(20,82); $dllLabel.Size=New-Object Drawing.Size(220,22); $dllLabel.Text='DLL name'; $form.Controls.Add($dllLabel)
$dll=New-Object Windows.Forms.ComboBox; $dll.Location=New-Object Drawing.Point(20,105); $dll.Size=New-Object Drawing.Size(220,25); $dll.DropDownStyle='DropDownList'
@('auto','dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll') | ForEach-Object {[void]$dll.Items.Add($_)}
$dll.SelectedIndex=0; $form.Controls.Add($dll)
$nrLabel=New-Object Windows.Forms.Label; $nrLabel.Location=New-Object Drawing.Point(260,82); $nrLabel.Size=New-Object Drawing.Size(220,22); $nrLabel.Text='NR backend'; $form.Controls.Add($nrLabel)
$nrBox=New-Object Windows.Forms.ComboBox; $nrBox.Location=New-Object Drawing.Point(260,105); $nrBox.Size=New-Object Drawing.Size(240,25); $nrBox.DropDownStyle='DropDownList'
@('auto','mochizuki','daniel','lmxxf') | ForEach-Object {[void]$nrBox.Items.Add($_)}
$nrBox.SelectedIndex=0; $form.Controls.Add($nrBox)
$nrDllLabel=New-Object Windows.Forms.Label; $nrDllLabel.Location=New-Object Drawing.Point(20,143); $nrDllLabel.Size=New-Object Drawing.Size(480,22); $nrDllLabel.Text='Optional nvngx_dlssnr.dll (310.9.16 / 310.8.0 for Daniel 0.8.0 & Mochi weights)'; $form.Controls.Add($nrDllLabel)
$nrDllPath=New-Object Windows.Forms.TextBox; $nrDllPath.Location=New-Object Drawing.Point(20,166); $nrDllPath.Size=New-Object Drawing.Size(380,25); $form.Controls.Add($nrDllPath)
$nrDllBrowse=New-Object Windows.Forms.Button; $nrDllBrowse.Location=New-Object Drawing.Point(410,164); $nrDllBrowse.Size=New-Object Drawing.Size(90,29); $nrDllBrowse.Text='Browse...'; $form.Controls.Add($nrDllBrowse)
$install=New-Object Windows.Forms.Button; $install.Location=New-Object Drawing.Point(300,218); $install.Size=New-Object Drawing.Size(95,34); $install.Text='Install'; $form.Controls.Add($install)
$cancel=New-Object Windows.Forms.Button; $cancel.Location=New-Object Drawing.Point(405,218); $cancel.Size=New-Object Drawing.Size(95,34); $cancel.Text='Cancel'; $cancel.DialogResult='Cancel'; $form.CancelButton=$cancel; $form.Controls.Add($cancel)
$picker=New-Object Windows.Forms.OpenFileDialog; $picker.Title='Select the game executable'; $picker.Filter='Executable files (*.exe)|*.exe'; $picker.CheckFileExists=$true
$nrPicker=New-Object Windows.Forms.OpenFileDialog; $nrPicker.Title='Select nvngx_dlssnr.dll (310.9.16.0 or 310.8.0.0)'; $nrPicker.Filter='DLL files (*.dll)|*.dll'; $nrPicker.CheckFileExists=$true
$browse.Add_Click({if($picker.ShowDialog() -eq 'OK'){$path.Text=$picker.FileName}})
$nrDllBrowse.Add_Click({if($nrPicker.ShowDialog() -eq 'OK'){$nrDllPath.Text=$nrPicker.FileName}})
$install.Add_Click({
    if(!(Test-Path -LiteralPath $path.Text -PathType Leaf)){[void][Windows.Forms.MessageBox]::Show('Select the game executable.','Setup','OK','Warning'); return}
    $install.Enabled=$false; $form.UseWaitCursor=$true
    try {
        $installArgs = @{
            GameDir   = ([IO.Path]::GetDirectoryName($path.Text))
            ProxyName = ([string]$dll.SelectedItem)
            NrBackend = ([string]$nrBox.SelectedItem)
        }
        if ($nrDllPath.Text -and (Test-Path -LiteralPath $nrDllPath.Text -PathType Leaf)) {
            $installArgs['NrDllPath'] = $nrDllPath.Text
        }
        & (Join-Path $PSScriptRoot 'Setup.Install.ps1') @installArgs *> $null
        [void][Windows.Forms.MessageBox]::Show('Installed.','Setup','OK','Information'); $form.Close()
    } catch {[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Setup','OK','Error')}
    finally {$form.UseWaitCursor=$false; $install.Enabled=$true}
})
[void]$form.ShowDialog()
