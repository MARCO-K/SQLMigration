<#
		Author: Marco Kleinert
		Version: 1.0
		Version 
		- 1.0 initial version

		.SYNOPSIS

		This script creates an output file for server and/or database role mermberships.

		.DESCRIPTION

		This script creates an output file for server and/or database role mermberships to re-create them on another instance.
		No memberships for system or builtin logins are included. No database roles for system datbases are included.

		.PARAMETER ServerInstance

		This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

		.PARAMETER roles

		This parameter is responsible to out server and/or database roles. One or both option can be used.

		.PARAMETER outputpath

		This is the outputpath where the file will be saved. The file name is create based on server/instance name and the date.
		If no path is given the file will be place into "MyDocuments" of the user.

		.EXAMPLE

		Export-Roles -ServerInstance SM10209\S3907 -roles 'database','server' -outputpath D:\temp -Verbose
#>
function Export-Roles{
	#requires -Version 3
	[cmdletbinding()]
	param([parameter(Mandatory=$true,ValueFromPipeline=$true)][string] $ServerInstance=$(throw 'ServerInstance required.')
		,[ValidateSet('database','server')] [string[]]$roles
		,[string] $outputpath=([Environment]::GetFolderPath('MyDocuments')))	
	
	begin{ 
		#Load assemblies
		[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

		#$ServerInstance = 'SM10209\S3907'
		#$outputpath=([Environment]::GetFolderPath('MyDocuments'))
		#create initial SMO object
		$server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance

		#creating outputpath
		$outputpath = Join-Path $outputpath -ChildPath 'roles'
		if(!(Test-Path -Path $outputpath )){New-Item -ItemType directory -Path $outputpath |  Out-Null }
		$filename = $ServerInstance.Replace('\','_') + '_' + (Get-Date -Format 'yyyyMMddHHmm') +'_roles.sql'
		$outfile = Join-Path -Path $outputpath -ChildPath $filename
		##collection of non-system logins
		$logins = ($server.Logins | Where-Object {$_.IsSystemObject -eq $false -and $_.Name -notlike 'NT *'  -and $_.Name -notlike '##*##'}).Name.Trim()
		Write-Verbose "writing scripts to: $outputpath"
	}
	process{
		if($roles -eq 'server'){
			#Server Roles
			write-verbose "Writing system role $rolename"
			$lscript = "use [master]`r`nGO"
			$lscript | Out-File -Append -FilePath $outfile
			foreach ($role in $server.roles)
			{
				$rolename = $role.name
				try { $rolemembers = $role.EnumMemberNames() }
				catch { $rolemembers = $role.EnumServerRoleMembers() }
				foreach ($rolemember in $rolemembers){ 
					if ($rolemember -in $logins)
					{

						try
						{
							$lscript = "EXEC sp_addrolemember @rolename = N'$rolename', @membername = N'$rolemember'"
							Write-verbose "Added $rolemember to $rolename server role."
							$lscript | Out-File -Append -FilePath $outfile
						}
						catch
						{
							Write-Error "Failed to add $rolemember to $rolename server role. $($_.Exception.Message)"
						}
					}
				}
			}
		}
		if($roles -eq 'database'){
			#database roles
			$dbs = $server.Databases  | Where-Object { $_.IsSystemObject -eq $false }
			foreach($db in $dbs){
				write-verbose "Changed to database $db"
				$lscript = "use $db`r`nGO"
				$lscript | Out-File -Append -FilePath $outfile
				foreach ($role in $db.roles)
				{
					$rolename = $role.name

					try { $rolemembers = $role.EnumMemberNames() }
					catch { $rolemembers = $role.EnumMembers() }
					foreach ($rolemember in $rolemembers){ 
						if ($rolemember -in $logins)
						{

							try
							{
								$lscript = "EXEC sp_addrolemember @rolename = N'$rolename', @membername = N'$rolemember'"
								Write-verbose "Added $rolemember to $rolename database role."
								$lscript | Out-File -Append -FilePath $outfile
							}
							catch
							{
								Write-Error "Failed to add $rolemember to $rolename database role. $($_.Exception.Message)"
							}
						}
					}
				}
			}
		}
	}
	end{ Write-verbose "Script created for role: $roles" }
}
			