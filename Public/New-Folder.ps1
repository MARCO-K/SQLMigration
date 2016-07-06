<#
		Author: Marco Kleinert
		Version: 1.0
		Version 
		- 1.0 initial version

		.SYNOPSIS

		This script creates a folder structure for exporting all objects to its own sub folder.

		.DESCRIPTION

		This script creates a folder structure for exporting all objects to its own sub folder.
		This folder structure including all files will be zipped later on.

		.PARAMETER rootpath

		This is the name of the root path containing every sub folder.

		.PARAMETER types

		This parameter is responsible to create a sub folder for each object type.


		.EXAMPLE

		New-Folder -rootpath D:\SQLMigration -types 'backups','configuration','jobs','logins','linkedserver','roles','schedules' -verbose
#>
function New-Folder{ 
	#requires -Version 3
	[cmdletbinding()]
	param(
		[parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$rootpath,
		[ValidateSet('backups','configuration','jobs','logins','linkedserver','roles','schedules')][string[]]$types
		)

	begin {
		If (Test-Path -Path $rootpath -PathType Container)
		{ Write-verbose "$rootpath already exists"}
		ELSE
		{ New-Item -Path $rootpath  -ItemType directory | out-null
		 Write-verbose "$rootpath created"}
	}
	
	process {
		foreach($path in $types) { 
			$NewFolder = Join-Path -Path $rootpath -ChildPath $path
			If(!(Test-Path $NewFolder -PathType Container)) {
				New-Item -ItemType Directory -Path $NewFolder | Out-Null
				Write-verbose "$NewFolder created"
			}
			else { Write-verbose "$NewFolder already exists"}
		}
	}
	
	
	end {}
}
