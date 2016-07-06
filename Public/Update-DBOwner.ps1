<#
    Author: Marco Kleinert
    Version: 1.0
    Version 
    - 1.0 initial version

    .SYNOPSIS

    This script updates the own of a user database.

    .DESCRIPTION

    This script updates the owner of a user database.

    .PARAMETER ServerInstance

    This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

    .PARAMETER dbname

    This is one or more names of the datbases where the owner will be changed. The parameter can be empty. In this case all available non-system datbases are used.

    .PARAMETER dbowner

    This is the name of the new dbowner. The parameter can be empty. In this case the "sa" account is used.

    .PARAMETER outputpath

    This is the outputpath where the file will be saved. The file name is create based on server/instance name and the date.
    If no path is given the file will be place into "MyDocuments" of the user.

    .EXAMPLE

    Update-SqlDbOwner -ServerInstance SM10209\S3907 -dbname 'test' -outputpath D:\temp -Verbose
#>
Function Update-SqlDbOwner
{

  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true)][string] $ServerInstance,
    [string[]]$dbname,
    [string]$dbowner,
    [string]$outputpath=([Environment]::GetFolderPath('MyDocuments'))
  )
	
  begin { 
    #Load assemblies
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
    #create initial SMO object
    if (!(Test-SQLServer $ServerInstance )) { return $false ; exit}
    
    $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
	
    if ($dbname.length -eq 0)
    {
      $databases = ($server.Databases | Where-Object { $server.databases.name -contains $_.name -and $_.IsSystemObject -eq $false }).Name
    }
    else { $databases = $dbname }
  }
  process { 
    foreach ($dbname in $databases)
    {
      if($dbname -notin ($server.databases).Name) { Write-verbose 'Database does not exist. Skipping dbowner update.'; continue }
			 
      $destdb = $server.databases[$dbname]		
      if ($destdb.owner -ne $dbowner)	{
        if ($destdb.Status -ne 'Normal') { Write-verbose 'Database status not normal. Skipping dbowner update.'; continue }
			
        if ($dbowner -eq $null -or $server.logins[$dbowner] -eq $null)
        {
          try
          { $dbowner = ($server.logins | Where-Object { $_.id -eq 1 }).Name }
          catch
          { $dbowner = 'sa' }
        }
			
        try
        {
          $destdb.SetOwner($dbowner)
          $destdb.Alter() 
          Write-Verbose "DBOwner changed for $destdb to $dbowner"
        }
        catch
        {
          Write-Error "Failed to update $dbname owner to $dbowner. $($_.Exception.Message)"
          return $false
        }
      }
      else { Write-verbose "Proper owner already set on $dbname" }
    }
  }
  end {
    $message = "DBOwner changed for `"$databases`".";
    return $true
  }
}
