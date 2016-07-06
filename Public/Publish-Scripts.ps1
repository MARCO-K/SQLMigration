<#
	Author: Marco Kleinert
	Version: 1.0
	Version 
	- 1.0 initial version

	.SYNOPSIS

	This script runs all custom scripts stored in a directory.

	.DESCRIPTION

	This script runs all custom scripts stored in a directory in a specific order.
	The script uses an alphabetic sorting, e.g 01-sql.sql ... 10-end.sql.
	All scripts must have the suffix "sql".   

	.PARAMETER ServerInstance

	This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

	.PARAMETER rootpath

	This is the rootpath where all files are saved. Each object type has an own sub folder.

	.PARAMETER types

	This parameter triggers the type ob objects which will be restored from a specific subfolder.
	The allowed values are 'jobs', 'schedules', 'logins', 'linkedserver', 'custom','configuration'.

	.EXAMPLE

	Publish-Scripts -ServerInstance SM10209\S3907 -rootpath D:\temp -types 'custom' -verbose
#>
#requires -Version 3
function Publish-Scripts {
	[cmdletbinding()]
	param(
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
		[parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$rootpath,
		[parameter(Mandatory=$true,ValueFromPipeline=$True)][ValidateNotNull()][ValidateSet('jobs','schedules','logins','linkedserver','custom','configuration','roles')][string[]]$types,
		[string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
	
	)
	BEGIN {
		if(Test-Path -Path $rootpath) { 
			Write-Verbose "execute all script in subfolders in: $rootpath"
		}
	}
	PROCESS {
		try { 
			 foreach ($type in $types) {
				$sourcepath = Join-Path $rootpath -ChildPath $type
				Write-Verbose "execute all scripts in folder: $sourcepath"
				$files = Get-ChildItem -path $sourcepath -Filter *.sql | Where-Object { $_.Attributes -ne 'Directory'} | sort-object
				 foreach ($f in $files) 
				 { 
					 $out = $sourcepath + $f.name.split('.')[0] + '.txt' ; 
					 Write-Verbose "execute script: $f"
					 invoke-sqlcmd -ServerInstance $ServerInstance -InputFile $f.fullname | format-table | out-file -filePath $out 
				 }
			 }
		}
		catch {
			Write-Error "Failed to export scripts for $type : $($_.Exception.Message)" 
			return $false
		}
	}
	END {
		$message = "Imported source objects `"$types`".";
		#Write-Host $message
		return $true
	}

}