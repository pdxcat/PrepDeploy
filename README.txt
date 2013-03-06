Reap-Computer.ps1

Written by pfaffle (8/24/12)

Removes a computer from Active Directory and SCCM in preparation for being re-deployed.

It takes the following steps:
1. Finds computer in AD if it exists.
2. Dumps current group membership to a file.
3. Deletes the Computer object from AD.
4. Deletes the Computer object(s) from SCCM.

Usage: .\PrepDeploy.ps1 [computername],[computername],[...]

This script needs a lot of work ... sorry for how ugly it is. It is functional though, mostly.