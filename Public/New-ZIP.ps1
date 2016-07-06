<#
		Author: Marco Kleinert
		Version: 1.0
		Version 
		- 1.0 initial version

		.SYNOPSIS

		This script creates a ZIP file for all files in the rootpath.

		.DESCRIPTION

		This script creates a ZIP file for all files in the rootpath.
        All subfolders and files are included.

		.PARAMETER rootpath

		This is the name of the root path containing every sub folder.

		.EXAMPLE

		New-ZIP -rootpath D:\SQLMigration -verbose
#>
function New-ZIP{ 
	#requires -Version 3
	[cmdletbinding()]
	param(
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$rootpath
		,[string]$destination=([Environment]::GetFolderPath('MyDocuments'))
	)

	begin {
		try {
			(Test-Path -Path $rootpath -PathType Container)
			Write-verbose "Creating ZIP file in $rootpath"
		}
		catch { Write-Error "$rootpath does not exist - $($_.Exception.Message)"
		}
	}
	
	process {
	
		If(!(Test-Path $destination -PathType Container)) {
			New-Item -ItemType Directory -Path $destination | Out-Null
			Write-verbose "$destination created"
		}
		else { Write-verbose "$destination already exists"}
		$filename = 'SQLMigration' + (Get-Date -Format 'yyyyMMddHHmm') +'.zip'
		$zipfile = Join-Path -Path $destination -ChildPath $filename
			
		try { 
			Write-verbose "Creating $zipfile"
			Add-Type -assembly 'system.io.compression.filesystem'
			[io.compression.zipfile]::CreateFromDirectory($rootpath, $zipfile) 
		}
		catch { 
			Write-Error "Could not create ZIP file:  $($_.Exception.Message)"
			return $false
		}

		
	}
	END {
		$message = "Created ZIP file for source objects `"$zipfile`".";
		return $true
	}
}
