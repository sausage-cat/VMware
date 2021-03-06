function Get-ScriptDirectory {
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	Split-Path $Invocation.MyCommand.Path
}

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

#We need to use these modules
$Modules = 'VMware.VimAutomation.HorizonView'

$strWorkingDirectory = Get-ScriptDirectory

$ConnectionServer = "Your Horizon connection server"
Connect-HVServer -Server $ConnectionServer

$Pool_list = Get-HVPoolSummary

Write-Host "HV POOLS:" $Pool_list.DesktopSummaryData.Name

foreach ($Pool in $Pool_list.DesktopSummaryData.Name)
{

	$PoolVM = Get-HVPool -PoolName $Pool | Get-HVPoolSpec | ConvertFrom-Json
	Write-Host `n"POOL Name:" $Pool
	Write-Host -ForegroundColor Green "Parent VM:" $poolVM.AutomatedDesktopSpec.virtualCenterProvisioningSettings.VirtualCenterProvisioningData.parentVm

	$PoolVM = Get-HVPool -PoolName $pool
	Write-Host -ForegroundColor Yellow "Parent Snapshot:" $poolVM.AutomatedDesktopData.VirtualCenterNamesData.SnapshotPath

}
