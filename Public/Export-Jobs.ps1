function Export-Jobs { 
	<#
			Author: Marco Kleinert
			Version: 1.0
			Version 
			- 1.0 initial version

			.SYNOPSIS

			This script creates an output file for all non-builtin jobs.

			.DESCRIPTION

			This scripts uses a given job name or uses all non-builtin jobs and retrieves all relavant information to re-create them on another instance.
			Finally the script can apply the created statement directly on a specified server\instance or can save it to a file.

			.PARAMETER ServerInstance

			This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

			.PARAMETER ApplyTo

			This is the name of a possible target instance.

			.PARAMETER jobs
			This is a single or a list of jobs where the create statement is needed for re-creation. The parameter can be empty. In this case all available non-builtin jobs are used.

			.PARAMETER outputpath

			This is the outputpath where the file will be saved. The file name is create baseed on server/instance name and the date.
			If no path is given the file will be place into "MyDocuments" of the user.

			.EXAMPLE

			Export-Jobs -ServerInstance SM10209\S3907 -outputpath D:\temp -verbose
	#>
	#requires -Version 3

	[cmdletbinding()]
	param([parameter(Mandatory=$true)][string] $ServerInstance
		,[string] $ApplyTo
		,[string[]] $jobs
		,[string] $outputpath=([Environment]::GetFolderPath('MyDocuments')))

	#Load assemblies
	[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

	#create initial SMO object
	$server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance

	#creating outputpath
	$outputpath = Join-Path $outputpath -ChildPath 'jobs'
	if(!(Test-Path -Path $outputpath )){New-Item -ItemType directory -Path $outputpath}
	Write-Verbose "writing scripts to: $outputpath"
	
	#Make sure we script out the SID
	$so = new-object microsoft.sqlserver.management.smo.scriptingoptions
	$so.LoginSid = $true

	#If no jobs explicitly declared, assume all non-system jobs
	if(!($jobs)){ $jobs = ($server.JobServer.Jobs  | Where-Object {$_.Name -notlike 'DBA Job*'} ).Name.Trim()}
	else { $jobs = $jobs.Trim() }



	if ($jobs -ne $null)
	{
		#loop through jobs
		ForEach ($job in $jobs)
		{
    
			$j = $server.JobServer.Jobs[$job]
			$lscript = $j.Script() 
        
			#set output filename
			$filename = $ServerInstance.Replace('\','_') + '_' + (Get-Date -Format 'yyyyMMddHHmm')+'-job_'+$job.Replace(' ','_')+'.sql'
			$outfile = Join-Path -Path $outputpath -ChildPath $filename
			Write-Verbose "creating script for job: $job -> $outfile"
        
			#script login to out file
			$lscript | Out-File -Append -FilePath $outfile
               
			#if ApplyTo is specified, execute the login creation on the ApplyTo instance
			If($ApplyTo){
				$smotarget = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ApplyTo

				if(!($smotarget.JobServer.Jobs.Jobschedules.name -contains $job)){
					$smotarget.Databases['tempdb'].ExecuteNonQuery($lscript)
					$outmsg='Job ' + $job + ' created.'
				}
				else{
					$outmsg='Job ' + $job + ' skipped, already exists on target.'
				}
				Write-Verbose $outmsg
			}
			
		}
	}
}
