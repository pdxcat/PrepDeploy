param (
	[String[]]$ComputerName = $env:computername,
	[boolean]$Force = $false
)
Import-Module ActiveDirectory
$SCCMServer = "CLARENCE"
$SiteName = "CAT"
$LogFilePath = "\\idunn\InstalledSoftware\Groups"

foreach ($Comp in $ComputerName) {
	$Comp = $Comp.ToUpper()
	$Exists = $true
	$Failed = $false
	
	Write-Host -NoNewline "Searching for $Comp in Active Directory... "
	try { $CompObject = Get-ADComputer "$Comp$" }
	catch {	$Failed = $true	}
	
	# Get a list of all Groups that the computer is a member of, for our records.
	if ($Exists -and !$Failed) {
		Write-Host -ForegroundColor Green "Success!"
		Write-Host -NoNewline "Retrieving current group membership... "
		try {
			$Groups = Get-ADPrincipalGroupMembership ($CompObject.DistinguishedName)
		} catch { $Failed = $true }
		
		# Output the list of group names to a file.
		if (!$Failed) {
			Write-Host -ForegroundColor Green "Success!"
			Write-Host -NoNewline "Dumping group membership... "
			try {
				$Groups | Select-Object -ExpandProperty Name | Out-File "$LogFilePath\$Comp.txt" -Encoding ASCII -Force
			} catch { $Failed = $true }
			
			# Remove the computer from Active Directory.
			if (!$Failed) {
				Write-Host -ForegroundColor Green "Success!"
				Write-Host -NoNewline "Removing from Active Directory... "
				# Remove Hyper-V child object, if it exists.
				try { Remove-ADObject -Identity ("CN=Windows Virtual Machine," + $Compobject.DistinguishedName) -Confirm:$false }
				catch {
					# Is not a VM.
				}
				try { 
					Remove-ADObject -Identity ($CompObject.DistinguishedName) -Confirm:$false
				} catch { $Failed = $true }
				
				# Remove the computer from SCCM.
				if (!$Failed) {
					Write-Host -ForegroundColor Green "Success!"
					Write-Host -NoNewline "Removing from SCCM... "
					try {
						# Find all instances (even 'Obselete' and non-'Active' instances)
						# of the computer in SCCM's database.
						$ResourceID = Get-WmiObject	-ComputerName $SCCMServer `
							-Query "SELECT ResourceID FROM SMS_R_System WHERE Name LIKE `'$Comp`'" `
							-Namespace "root\sms\site_$SiteName"
						# Delete each object.
						$ResourceID | ForEach-Object { 
							$CompResource = [wmi]$_.__PATH
							$CompResource.psbase.delete()
						}
					} catch { $Failed = $true }
					if (!$Failed) {
						Write-Host -ForegroundColor Green "Success!"
					}
				}
			}
		}
	}
	
	if (!$Failed) {
		Write-Host "$Comp removed from AD and SCCM."
	} else {
		Write-Host -ForegroundColor Red "Failed!"
		Write-Host "$Comp removal failed."
	}
}