<#
		Author: Marco Kleinert
		Version: 1.0
		Version 
		- 1.0 initial version

		.SYNOPSIS

		This script runs all scripts stored in a directory to re-create linked server objects.

		.DESCRIPTION

		This script runs all  scripts stored in a directory in a specific order.
		The script uses an alphabetic sorting.
		All scripts must have the suffix "sql".   

		.PARAMETER ServerInstance

		This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

		.PARAMETER rootpath

		This is the rootpath where all files are saved. Each object type has an own sub folder.

		.EXAMPLE

		Import-LinkedServer -ServerInstance SM10209\S3907 -rootpath D:\temp -verbose
#>
#requires -Version 3
function Import-LinkedServer { 
  [cmdletbinding()]
  param([parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$rootpath,
    [string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
	
	)
BEGIN {
	$rootpath = Join-Path $rootpath -ChildPath 'linkedserver'
	Write-Verbose "execute all scripts in folder: $rootpath"
}
PROCESS {
	try { 
		if(Test-Path -Path $rootpath) {
			$files = Get-ChildItem -path $rootpath -Filter *.sql | Where-Object { $_.Attributes -ne 'Directory'} | sort-object
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
					Write-Error "Failed to apply configuration to `"$ServerInstance`". $($_.Exception.Message)"
					return $false
				}
  }
  end {
    $message = "Configuration applied to `"$ServerInstance`".";
    return $true
  }
}