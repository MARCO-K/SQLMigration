<#
    Author: Marco Kleinert
    Version: 1.0
    Version 
    - 1.0 initial version

    .SYNOPSIS

    This script drops a given database or a list of databases.

    .DESCRIPTION

    This script drops a given database or a list of databases. 

    .PARAMETER ServerInstance

    This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

    .PARAMETER databases

     A given database or a list of databases.

    .EXAMPLE

    Remove-Database -ServerInstance SM10209\S3907 -databases test -verbose
#>
#requires -Version 3
function Remove-Database { 
  param( [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$databases,
    [string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
  )

BEGIN {
    #Load assemblies
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
    #create initial SMO object
    $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
}
 
Process {   
  try {
    $names = ($server.databases | Where-Object {$_.IsSystemObject -eq $false -and $_.Name -notlike 'NT *'  -and $_.Name -notlike '##*##'}).Name.Trim()
    foreach($database in $databases){
      if($database -in $names){

        #drop  databases
        if($server.Databases.Contains($database))
            { $server.Databases[$database].Drop() }

        Write-verbose "Database $database dropped"
      }
      else { Write-verbose "$database does not exist" }
    }
    }
  catch { Write-host -ForegroundColor Red "$databases not dropped" }
}
end {
    $message = "Database dropped on `"$ServerInstance`".";
    return $true
  }
	
}