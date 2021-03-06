<#
.SYNOPSIS
   Clone the golden master to a deployment VM with multiple ram sizes
.DESCRIPTION
   Clone parent vm and then take a snapshot for each of the Ram sizes defined, do instant clone fixes and tag cleanup. You can then deploy to pools with HZ_Update_Pools.
 #>

#Set working dir to same as script folder
function Get-ScriptDirectory {
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	Split-Path $Invocation.MyCommand.Path
}

#Test we have Powercli
function Test-module {
	if ((Get-Module $module) –eq $NULL)
	{
		# If not loaded – Notify user with required details
		#
		Write-Host "This Script requires $module"
		Write-Host "Check https://www.powershellgallery.com"
		exit
	}
	else { Import-Module $module }
}

#Connect to our vCenters
function VcenterConnect {
	$vcenters = @("your-Vcenter")
	Write-Host -ForegroundColor Blue -BackgroundColor White "Connecting to vCenters, please wait.."
	$VC = Connect-VIServer $vcenters -wa 0
	if ($VC.IsConnected)
	{
		Write-Host -ForegroundColor Blue -BackgroundColor White "Connected to $vc" `n
		return $Connected = $true
	}
	else { Write-Host "Error connecting to $vcenters"
		return $Connected = $false
	}
}

#Start here
$strWorkingDirectory = Get-ScriptDirectory

#Required modules
$Modules = 'VMware.VimAutomation.Core'

#Test we have modules installed
foreach ($module in $modules)
{ Test-module $module }

#Check if we are connected to vCenter, if not connect.
if (!$Connected)
{
	$Connected = VcenterConnect
}

#Just stop if failed to connect
if ($connected -eq $false)
{
	Write-Host -ForegroundColor Red "Could not connect to Vcenter!"
	exit
}

#Ram Sizes for Horizon pools
$Ramsizes = @(4,8)

#Get short month
$Now = Get-Date
$Now = (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($Now.Month)
$Date = Get-Date -Format "dd/MM/yyyy"

#Your master image
$GoldenMaster = "Master-Windows-10"

#New clone to be pool parent-month
$CloneName = "Deploy-Windows-10-" + $now

#Set destination Vcenter folder
$CloneFolder = Get-Folder "DEPLOY-IC"

#Reset changeblk and Namespacemgr DB on master before clone
################

$Prompt = Read-Host "Enter golden/deploy image VM name, Press enter to accept the default [$($GoldenMaster)]"
$Prompt = ($GoldenMaster,$Prompt)[[bool]$Prompt]

$NamespacemgrValue = Get-VM $Prompt | Get-AdvancedSetting | Select-Object name,value | Where-Object name -EQ namespaceMgr.dbFile
Write-Host -ForegroundColor Green $Prompt "Namespace -" $NamespacemgrValue

$Changeblk = Get-VM $Prompt | Get-AdvancedSetting | Select-Object name,value | Where-Object name -EQ ctkEnabled
Write-Host -ForegroundColor Green $Prompt "Changeblk -" $Changeblk

New-AdvancedSetting -Entity $Prompt -Name namespaceMgr.dbfile -Value "" -Force:$true -Confirm:$false
New-AdvancedSetting -Entity $Prompt -Name ctkEnabled -Value FALSE -Force:$true -Confirm:$false
New-AdvancedSetting -Entity $Prompt -Name scsi0:0.ctkEnabled -Value FALSE -Force:$true -Confirm:$false

sleep -Seconds 5

#################

#Clone to new VM
Write-Host -ForegroundColor Green "Creating $CloneName into $CloneFolder..."
$Task = New-VM -VM $Prompt -Name $CloneName -ResourcePool "Horizon" -Datastore "Horizon Datastore" -Location $CloneFolder -RunAsync
while ($task.ExtensionData.Info.State -eq "running") {
	sleep 1
	$task.ExtensionData.UpdateViewData('Info.State')
}

sleep -Seconds 35

#Change ram size and then snapshot
foreach ($Ram in $Ramsizes)
{
	Get-VM $CloneName | Set-VM -MemoryGB $Ram -Confirm:$false
	sleep -Seconds 35
	Get-VM $CloneName | New-Snapshot -Name "Win10-Golden-$now-$ram" -Description "Ram $ram GB. Update for $date."
	sleep -Seconds 35
}

#Block from TSM backup size so we don't get changeblocks
New-TagAssignment -Entity $CloneName -Tag "Excluded"

#Clear TSM backup notes
Get-VM $CloneName | Set-VM -Description " " -Confirm:$false

Write-Host -ForegroundColor Yellow -BackgroundColor Cyan "Cloned to $CloneName - All done!"
