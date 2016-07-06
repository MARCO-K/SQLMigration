	<#
			Author: Marco Kleinert
			Version: 1.0
			Version 
			- 1.0 initial version

			.SYNOPSIS

			This script re-creates all schedules saved in a directory.

			.DESCRIPTION

			This scripts uses a given schedule name and retrieves all relavant information to re-create them on another instance.
			Finally the script can apply the created statement directly on a specified server\instance or can save it to a file.

			.PARAMETER ServerInstance

			This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

			.PARAMETER rootpath

			This is the rootpath where all files are saved. Each object type has an own sub folder.

			.EXAMPLE

			Import-Schedules -ServerInstance SM10209\S3907 -rootpath D:\temp -verbose
	#>
	#requires -Version 3
function Import-Schedules { 	
[cmdletbinding()]
param([parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
  [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$rootpath,
  [string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
)

BEGIN {
  $rootpath = Join-Path $rootpath -ChildPath 'configuration'
  Write-Verbose "execute all scripts in folder: $rootpath"
  #Load assemblies
  [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
  #create initial SMO object
  $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
} 
Process { 
  try {
    if(Test-Path -Path $rootpath) { 
      $files = Get-ChildItem -path $rootpath -Filter *.sql | Where-Object { $_.Attributes -ne 'Directory'} | sort-object -desc
      foreach ($f in $files) 
      { 
        $out = $outputpath + $f.name.split('.')[0] + '.txt' ; 
        Write-Verbose "execute script: $f"
        invoke-sqlcmd -ServerInstance $ServerInstance -InputFile $f.fullname | format-table | out-file -filePath $out 
      }
    }
  }
  catch
				{
					Write-Error "Failed to apply schedules to `"$ServerInstance`". $($_.Exception.Message)"
					return $false
				}
  }
end {
    $message = "Schedules applied to `"$ServerInstance`".";
    return $true
  }
	
}