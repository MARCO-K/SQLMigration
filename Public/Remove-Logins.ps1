<#
    Author: Marco Kleinert
    Version: 1.0
    Version 
    - 1.0 initial version

    .SYNOPSIS

    This script removes a given login or a list of logins.

    .DESCRIPTION

    This script     removes a given login or a list of logins.  

    .PARAMETER ServerInstance

    This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

    .PARAMETER logins

    A given login or a list of logins.

    .EXAMPLE

    Remove-Logins -ServerInstance SM10209\S3907 -logins 'u-dom1\abc123 -verbose
#>
#requires -Version 3
function Remove-Logins { 
  param( 
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)][ValidateNotNullOrEmpty()][string]$ServerInstance,
    [string[]]$logins )

  #Load assemblies
  [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

  #create initial SMO object
  $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance

  try {
    $names = ($server.Logins | Where-Object {$_.IsSystemObject -eq $false -and $_.Name -notlike 'NT *'  -and $_.Name -notlike '##*##'}).Name.Trim()
    foreach($login in $logins){
      if($login -in $names){
        #drop database users
        foreach($database in $server.Databases) {
          if($database.Users.Contains($login))
            { $database.Users[$login].Drop() }
        }
        #drop server logins
        if($server.Logins.Contains($login))
            { $server.Logins[$login].Drop() }

        Write-verbose "Permissions for $logins revoked"
      }
      else { Write-verbose "$login does not exist" }
    }
    }
  catch { Write-host -ForegroundColor Red "$logins not dropped" }
}
