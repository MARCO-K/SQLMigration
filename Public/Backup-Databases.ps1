function Backup-Databases { 
	<#
			Author: Marco Kleinert
			Version: 1.0
			Version History:

			- 1.0 inital creation

			.SYNOPSIS

			This script will backup one or more databases.

			.DESCRIPTION

			The backup script is backing up a list of databases. These list can be provided as input parameter or all databases except the system database will be processed.
			It writes the backup files to the path provided on the local disk. 

			.PARAMETER ServerInstance

			This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

			.PARAMETER dbname

			This is one or more names of the databases you need to backup. The parameter can be empty. In this case all availavble non-system databases are used.

			.PARAMETER backupDirectory

			This is the outputpath where the backup file will be placed. The file name is create baseed on server/instance name and the date.
			If no path is given the file will be place into default BackupDirektory.

			.PARAMETER copyOnly

			With this parameter you can decide if you want to create a copyOnly backup.

			.EXAMPLE

			Backup-Databases -ServerInstance sm10209\s3907 -dbname master -copyOnly -verbose
	#>
	
	[cmdletbinding()]
	param([parameter(Mandatory=$true)][string]$ServerInstance,
		[string[]]$dbname,
		[parameter(Mandatory=$true)][string]$backupDirectory,
		[string]$action='Database', 
		[switch]$copyOnly = $true
	)

	#Load assemblies
	$smoAssembly = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
	$smoVersion  = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO').GetName().Version.Major
	[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended')
	[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo')
	[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoEnum') 
	#create initial SMO object
	$server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance

	#If no backupDirectory explicitly declared, assume the default backupDirectory
	if(!$backupDirectory) {$backupDirectory = $server.BackupDirectory}

	#If no databases explicitly declared, assume all non-system databases
	if(!($dbname))
	{$dbs = ($server.Databases | Where-Object {$_.IsSystemObject -eq $false -and $_.Name -ne 'SSISDB' }).Name.Trim()}
	else 
	{if ( !$server.Databases -in $dbname) {throw "Database $dbname does not exist on $($server.Name)."}
	$dbs = $dbname }

	#backup each selected databases
	foreach ($database in $dbs)  
	{
		$dbName = $database
    
		$timestamp = Get-Date -format yyyy-MM-dd-HHmmss
		$targetPath = $backupDirectory + '\' + $dbName + '_' + $timestamp + '.bak'
    
		Write-Verbose "Backup $($server.Name) $dbname to $targetPath"
    
		#create the backup object
		$smoBackup = New-Object ('Microsoft.SqlServer.Management.Smo.Backup')
		$smoBackup.Action = $action
		$smoBackup.BackupSetDescription = "$action backup of " + $dbName
		$smoBackup.BackupSetName = $action
		$smoBackup.Database = $dbName
		$smoBackup.MediaDescription = 'Disk'
		$smoBackup.Devices.AddDevice($targetPath, 'File')

		if ($copyOnly)
		{ if ($server.Information.Version.Major -ge 9 -and $smoVersion -ge 10)
			{ $smoBackup.CopyOnly = $true }
			else
			{ throw 'CopyOnly is supported in SQL Server 2005(9.0) or higher with SMO version 10.0 or higher.' }
		}
		#do the real backup
		$smoBackup.SqlBackup($server)
	}


}