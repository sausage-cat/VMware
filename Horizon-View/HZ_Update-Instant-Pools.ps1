##Update instant clone pools with a 30 min gap per pool

<#
.SYNOPSIS
   Update multiple Horizon pools with at once with same parent VM image and snaphot.
.DESCRIPTION
   The script  will do a scheduled update for multiple pools with a gap between Image Pushes
.PARAMETER ParentVM
   Name of the golden master VM to clone from (manadatory).
.PARAMETER SnapshotVM
   Name of the snapshot to use for cloning (mandatory).
.PARAMETER DelayStart
   Amount of hours delay before update (optional)

.EXAMPLE
   .\HZ_Update-Instant-Pools.ps1 -ParentVM Deploy-Win10-Feb-4 -SnapshotVM Win10-golden-4 -DelayStart 6
   
#>


[CmdletBinding()]
param(

	[Parameter(Mandatory = $True)]
	[string]$ParentVM,

	[Parameter(Mandatory = $True)]
	[string]$SnapshotVM,

	[Parameter(Mandatory = $False)]
	[string]$DelayStart
)

function Schtime ($Now)
{
	#Gap between updates
	$Schedule = New-TimeSpan -Minutes 30

	$Schedule = $Now + $Schedule

	return $Schedule
}

function Get-ScriptDirectory {
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	Split-Path $Invocation.MyCommand.Path
}

function Test-Module {
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
$Modules = 'VMware.VimAutomation.HorizonView','VMware.Hv.Helper'

foreach ($module in $modules)
{ Test-module $module }

$strWorkingDirectory = Get-ScriptDirectory

$ConnectionServer = "Your Horizon connection server"

Connect-HVServer -Server $ConnectionServer

#If we want to schedule out of hours start time set delay using param
if ($DelayStart)
{
	$Delay = New-TimeSpan -Hours $DelayStart
	$Now = (Get-Date) + $Delay
	$Schedule = Schtime ($Now)
}

else
{
	$Now = (Get-Date)
	$Schedule = Schtime ($Now)
}

#Put the pool names to be updated in a text file
$Pools = Get-Content $strWorkingDirectory'\horizon_pools.txt'
if (!$Pools) { Write-Host "No pools in text file!" Exit }


foreach ($Pool in $Pools)

{
	Write-Host -ForegroundColor Green "Updating $Pool with $ParentVM VM and $SnapshotVM Snapshot at: $Schedule"
	Start-HVPool -Pool $Pool -LogoffSetting WAIT_FOR_LOGOFF -ParentVM $ParentVM -SchedulePushImage -SnapshotVM $SnapshotVM -StartTime $Schedule -StopOnFirstError $True
	$Schedule = Schtime ($Schedule)
}
