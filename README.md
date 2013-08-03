PrepDeploy.ps1
==============

Prepares a computer to be deployed in the CAT environment by either removing it from our records entirely (if it is getting a new name) or by simply removing it from Active Directory so that it can be deployed fresh without inheriting any prior configuration state.

Usage
-----
    PrepDeploy.ps1 -Destroy [computername],[computername],[...]
    PrepDeploy.ps1 -Redeploy [computername],[computername],[...]
