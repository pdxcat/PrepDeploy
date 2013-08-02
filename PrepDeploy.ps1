<#
    .Synopsis
    Removes a computer from AD and SCCM, if desired

    .Description
    Passing the -Destroy flag removes the given computer from both AD and SCCM and creates a textfile with the groups 
    the object was a member of.  Passing the -Redeploy flag only deletes the object from AD and creates the same textfile.
  
    .Example
    .\prepdeploy bulbasaur -Destroy
    Succesfull output will be:
    Searching for bulbasaur in Active Directory... Success!
    Retrieving current group membership... Success!
    Storing group membership... Success!
    Removing from Active Directory... Success!
    Removing from SCCM... Success!

    .Example
    .\prepdeploy bulbasaur -Redeploy
    Succesfull output will be:
    Searching for bulbasaur in Active Directory... Success!
    Retrieving current group membership... Success!
    Storing group membership... Success!
    Removing from Active Directory... Success!
#>

param(
    [Parameter(Mandatory=$true)][String] $CompName,
    [switch]$Destroy,
    [switch]$Redeploy
)

Import-Module ActiveDirectory 
$SCCMServer = "Itzamna"
$SiteName = "KAT"
$LogFilePath = "\\normandy\c$\temp\Groups"
$Success = 'Write-Host -ForegroundColor Green "Success!"'
$Failed = 'Write-Host -ForegroundColor Red "Failed!"'

## This function tests if the computer exsists in Active Directory.
## If the computer exists then it will return the computer object. 
## If the computer doesn't exists in active directory then returns null.   
function test-ADComp{
    Write-Host -NoNewline "Searching for $CompName in Active Directory... "
    try{
        $ComputerObject = Get-ADComputer $CompName
        invoke-expression $Success
    }catch{
        $ComputerObject = $NULL
        Write-Host -ForegroundColor Red "Doesn't Exist"
    }
    return $ComputerObject
}

## This function stores list of AD groups in a text file to a specified location.
## Inputs: It takes a object with the list of AD groups. 
## Outputs: Stores the list to a text file. 
function store-GroupMembership{
param(
    [object]$Groups
)
    Write-Host -NoNewline "Storing group membership... "
    try {
	    $Groups | Sort-Object | Select-Object -ExpandProperty Name | Out-File "$LogFilePath\$CompName.txt" -Encoding ASCII -Force
        Invoke-Expression $Success
	} catch {
        Invoke-Expression $Failed
    }
}

## This Function retrieves what AD groups the computer is apart of. 
## Input: AD Computer object. 
## Output: Calls store-GroupMembership to store the group list.
function get-GroupMembership{
    param(
        [object]$computerobject = $null
    )
    Write-Host -NoNewline "Retrieving current group membership... "
    try{
        $Groups = Get-ADPrincipalGroupMembership ($ComputerObject.DistinguishedName)
        Invoke-Expression $Success
        store-GroupMembership $Groups
    }catch{
        Write-Host -ForegroundColor Red "Couldn't Get Group Membersheip"
        Write-Host -ForegroundColor Red "Exiting Script."

    }
}

## This Function deletes the computer from AD.
## Input: AD Computer Object 
## Output: Will out Success and Failed. 
function remove-ComputerAD{
    param(
        [object]$ComputerObject
    )

    ## Used to see if the computer is a VM or not. 
    $filter = "(&(objectClass=serviceConnectionPoint)(CN=Windows Virtual Machine))" 
    $isVM = Get-ADObject –LDAPFilter $filter | select -ExpandProperty Distinguishedname | where{$_ -match $CompName}
    
    ## Start the deleteing processes.
    Write-Host -NoNewline "Removing from Active Directory... "
    if($isVM -eq $null){
        try{
            Remove-ADObject -Identity ($ComputerObject.DistinguishedName) -Confirm:$false
            Invoke-Expression $Success
        }catch{
            Invoke-Expression $Failed
        }
      
    }else{
        try{
            Remove-ADObject -Identity ("CN=Windows Virtual Machine," + $ComputerObject.DistinguishedName) -Confirm:$false 
            Invoke-Expression $Success
        }catch{
            Invoke-Expression $Failed
        }
    }
}


## This Function deletes the computer from SCCM
Function remove-ComputerSCCM{
    Write-Host -NoNewline "Removing from SCCM... "
    try {
		# Find all instances (even 'Obselete' and non-'Active' instances)
		# of the computer in SCCM's database.
		$ResourceID = Get-WmiObject	-ComputerName $SCCMServer `
							-Query "SELECT ResourceID FROM SMS_R_System WHERE Name LIKE `'$CompName`'" `
							-Namespace "root\sms\site_$SiteName"
		# Delete each object.
        if ($ResourceID -ne $null)
        {
	        $ResourceID | ForEach-Object { 
		        $CompResource = [wmi]$_.__PATH
		        $CompResource.psbase.delete()
            }
            Invoke-Expression $Success
        }
        else
        {
            write-host -ForegroundColor Red "Doesn't Exist"
        }
    }catch{
        Invoke-Expression $failed
    }
}

if (($Destroy -eq $True) -and ($Redeploy -eq $True))
{
    write-host -ForegroundColor Red "Both Destroy and Redeploy can't be selected together, please select only one"
}

elseif ($Destroy -eq $True)
{
    $ADObject = test-ADComp $CompName
    if($ADObject -ne $null){
        get-GroupMembership $ADObject
        remove-ComputerAD $ADObject
    }
    remove-ComputerSCCM
}
elseif ($Redeploy -eq $True)
{
    $ADObject = test-ADComp $CompName
    if($ADObject -ne $null){
        get-GroupMembership $ADObject
        remove-ComputerAD $ADObject
  
    }
}

else
{
    write-host -ForegroundColor Red "Please specify flag:"
    write-host -ForegroundColor Red "-Destory if you want to delete from AD and SCCM"
    write-host -ForegroundColor Red "-Redeploy if you want to delete from AD only"
}
