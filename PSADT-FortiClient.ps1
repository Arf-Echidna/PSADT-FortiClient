<#
.Synopsis
   Create a PSADT wrapper for the latest version of FortiClient VPN
.DESCRIPTION
   Downloads PSADT from Github and Forticlient from the vendor, wraps it in PSADT with very basic switches (/qn)
   Add any additional arguments, like .mst or install commands, to the "InstallSwitches" variable. 
   Utilizes PSADT cmdlet "Remove-MSIApplications" for uninstall by name. 
.EXAMPLE
   Just run it :) 
.INPUTS
   Value of "InstallSwitches" can be changed.  Add any params that you want to apply during "Execute-MSI" (PSADT Cmdlet).
.OUTPUTS
   Stores output to "C:\Temp\Completed Packages". 
.NOTES
   This probably won't work for very long, and I'm not sure why I bothered. 
#>


## Variables + start a web client
$App = "FortiClient"
$InstallSwitches = "/qn"
$Client = New-Object System.Net.WebClient
$Url = "https://filestore.fortinet.com/forticlient" 
$Web = invoke-webrequest -uri $url
$Content = $web.content
$Regex = "FortiClientSetup_([\d.]+)_x64\.zip"
$Matches = [regex]::Matches($Content, $Regex)


## We'll need this for popups later
Add-Type -AssemblyName PresentationCore,PresentationFramework

## Find all the versions in the returned string
$Versions = @()
foreach ($match in $Matches) {
    $Versions += $match.Groups[1].Value
}

## Sort out the highest version number
$Highest = $Versions | Sort-Object -Descending | Select-Object -First 1
Write-Host "The highest version of FortiClient x64 is $Highest" -foregroundcolor green

## Make a folder for this, we'll clean it up after... 
$rand = get-random -min 1 -max 999999999999
$DestPath = "C:\temp\$env:computername$rand\"
If (!(Test-Path $DestPath)){
    New-Item -ItemType Directory -Path $DestPath -ErrorAction SilentlyContinue
}

## Build the URL for the latest version and download.  Download PSADT while we're at it. 
$NewUrl = "$url/FortiClientSetup_$highest.zip"
$Client.DownloadFile("$NewUrl", "$DestPath\Forti.zip")
$Client.DownloadFile("https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/archive/refs/heads/master.zip", "$DestPath\PSADT.zip")

## Let's expand PSADT first
Expand-Archive "$DestPath\PSADT.zip" -Destination "$DestPath\PSADT"
$Toolkit = "$DestPath\PSADT\PSAppDeployToolkit-master\Toolkit"

## Let's move our install media to the \files\ dir...
$Dirfiles = "$Toolkit\Files"
if (!(Test-Path $DirFiles)){
New-Item -Itemtype Directory -Path "$Toolkit\Files" -ErrorAction SilentlyContinue}
Expand-Archive "$DestPath\Forti.zip" -Destination $Dirfiles
$MSIPath = Get-Childitem "$Toolkit\Files\" -Recurse | where-object -property "Name" -like "*.msi"
$MSIName = $MSIPath.name
$File = "$Toolkit\Deploy-Application.ps1"
$Username = $env:username 
$Date = Get-Date -Format "MM/dd/yyyy"

## ...And start replacing text in the .ps1 
$find = "<author name>"
$replace = "$Username"
(Get-Content $file).replace($find, $replace) | Set-Content $file
$find = "XX/XX/20XX"
$replace = "$Date"
(Get-Content $file).replace($find, $replace) | Set-Content $file
$find = '$appVersion = '''''
$replace = '[String]$appVersion = ''' + $Highest + ''''
(Get-Content $file).replace($find, $replace) | Set-Content $file
$find = '[String]$appName = '''''
$replace = '[String]$appName = ''' + $App + ''''
(Get-Content $file).replace($find, $replace) | Set-Content $file
$find = "## <Perform Installation tasks here>"
$replace = "## <Perform Installation tasks here> `n Execute-Msi -Path `"`$DirFiles\$MSIName`" -Parameters `"$InstallSwitches"""
(Get-Content $file).replace($find, $replace) | Set-Content $file
$find = "## <Perform Uninstallation tasks here>"
$replace = "## <Perform Uninstallation tasks here> `n Remove-MSIApplications -Name `"$App`""
(Get-Content $file).replace($find, $replace) | Set-Content $file


$Output = "C:\temp\Completed Packages"
If (!(Test-Path $Output)){
    New-Item -ItemType Directory -Path $Output -Force 
}

Move-Item $Toolkit -Destination "$Output\$App $Highest x64"
Remove-Item $DestPath -Recurse -Force  

[System.Windows.MessageBox]::Show("Successfully createed $App, version $Highest PSADT wrapper, at $Output",'Amazing, wow','OK','Information')