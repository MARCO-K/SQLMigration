function Export-LinkedServer { 
	<#
			Author: Marco Kleinert
			Version: 1.0
			Version 
			- 1.0 initial version

			.SYNOPSIS

			This script creates an output file for all non-builtin linked server.

			.DESCRIPTION

			This scripts uses a given linkedserver name or uses all non-builtin linked server and retrieves all relavant information to re-create them on another instance.
			Finally the script can apply the created statement directly on a specified server\instance or can save it to a file.

			.PARAMETER ServerInstance

			This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

			.PARAMETER ApplyTo

			This is the name of a possible target instance.

			.PARAMETER linkedserver
			This is a single or a list of linked server where the create statement is needed for re-creation. The parameter can be empty. In this case all available non-builtin linked server are used.

			.PARAMETER outputpath

			This is the outputpath where the file will be saved. The file name is create baseed on server/instance name and the date.
			If no path is given the file will be place into "MyDocuments" of the user.

			.EXAMPLE

			Export-Linkedserver -ServerInstance SM10209\S3907 -outputpath D:\temp -verbose
	#>
	#requires -Version 2
	[cmdletbinding()]
	param([parameter(Mandatory=$true)][string] $ServerInstance
		,[string] $ApplyTo
		,[string[]] $linkedservers
		,[string] $outputpath=([Environment]::GetFolderPath('MyDocuments')))

	#Load assemblies
	[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

	#create initial SMO object
	$server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance

	#creating outputpath
	$outputpath = Join-Path $outputpath -ChildPath 'linkedserver'
	if(!(Test-Path -Path $outputpath )){New-Item -ItemType directory -Path $outputpath}
	Write-Verbose "writing scripts to: $outputpath"
	
	#If no schedules explicitly declared, assume all non-system linkedserver
	if(!($linkedservers)){ $linkedservers = ($server.LinkedServers).Name }
	else { $linkedservers = $linkedservers.Trim() }

		#loop through linked server
		foreach($linkedserver in $linkedservers)
		{
			$ls = $server.LinkedServers[$LinkedServer]
			$lscript = $ls.Script() 

			#set output filename
			$filename = $ServerInstance.Replace('\','_') + '_' + (Get-Date -Format 'yyyyMMddHHmm') + "_linkedserver_$linkedserver.sql"
			$outfile = Join-Path -Path $outputpath -ChildPath $filename
			#Join-Path -Path $outputpath -ChildPath $filename
			Write-Verbose "creating script for linkedserver: $linkedserver -> $outfile"
        
			#script login to out file
			$lscript | Out-File -Append -FilePath $outfile
               
			#if ApplyTo is specified, execute the login creation on the ApplyTo instance
			If($ApplyTo){
				$smotarget = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ApplyTo

				if(!($smotarget.$server.LinkedServers.Name -contains $LinkedServer)){
					$smotarget.Databases['tempdb'].ExecuteNonQuery($lscript)
					$outmsg='Schedule ' + $LinkedServer + ' created.'
				}
				else{
					$outmsg='LinkedServer ' + $LinkedServer + ' skipped, already exists on target.'
				}
				Write-Verbose $outmsg

			}
		
	}
}