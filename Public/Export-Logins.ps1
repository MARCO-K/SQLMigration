function Export-Logins {
	<#

			.SYNOPSIS

			This script creates an output file for all non-builtin logins.

			.DESCRIPTION

			This scripts uses a given login name or uses all non-builtin logins and retrieves all relavant information to re-create them on another instance.
			For SQL logins the script creates a password hash. Finally the script can apply the created statement directly on a specified server\instance or can save it to a file.


			.PARAMETER ServerInstance

			This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

			.PARAMETER ApplyTo

			This is the name of a possible target instance.

			.PARAMETER logins

			This is a single or a list of logins where the create statement is needed for re-creation. The parameter can be empty. In this case all availavble non-builtin logins are used.

			.PARAMETER outputpath

			This is the outputpath where the files will be saved. The file name is create baseed on server/instance name and the date.
			If no path is given the file will be place into "MyDocuments" of the user.

			.EXAMPLE

			Export-Logins -ServerInstance SM10209\S3907 -outputpath D:\temp
	#>
	#requires -Version 2

	[cmdletbinding()]
	param([parameter(Mandatory=$true)][string] $ServerInstance
		,[string] $ApplyTo
		,[string[]] $logins
		,[string] $outputpath=([Environment]::GetFolderPath('MyDocuments')))
	#Load assemblies
	[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

	function ConvertTo-SQLHashString{
		param([parameter(Mandatory=$true)] $binhash)
		$outstring = '0x'
		$binhash | ForEach-Object {$outstring += ('{0:X}' -f $_).PadLeft(2, '0')}
		return $outstring
	}

	#create initial SMO object
	$server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance

	#creating outputpath
	$outputpath = Join-Path $outputpath -ChildPath 'logins'
	if(!(Test-Path -Path $outputpath )){New-Item -ItemType directory -Path $outputpath}
	Write-Verbose "writing scripts to: $outputpath"

	#Make sure we script out the SID
	$so = new-object microsoft.sqlserver.management.smo.scriptingoptions
	$so.LoginSid = $true

	#set output filename
	$filename = $ServerInstance.Replace('\','_') + '_' + (Get-Date -Format 'yyyyMMddHHmm') + '_logins.sql'
	$outfile = Join-Path -Path $outputpath -ChildPath $filename

	#If no logins explicitly declared, assume all non-system logins
	if(!($logins)){
		$logins = ($server.Logins | Where-Object {$_.IsSystemObject -eq $false -and $_.Name -notlike 'NT *'  -and $_.Name -notlike '##*##'}).Name.Trim()
	}

	foreach($loginname in $logins){
		#get login object
		$login = $server.Logins[$loginname]

		#Script out the login, remove the "DISABLE" statement included by the .Script() method
		Write-Verbose "creating script for job: $login -> $outfile"
		$lscript = $login.Script($so) | Where-Object {$_ -notlike 'ALTER LOGIN*DISABLE'}
		$lscript = $lscript -join ' '

		#If SQL Login, sort password, insert into script
		if($login.LoginType -eq 'SqlLogin'){

			$sql = "SELECT convert(varbinary(256),password_hash) as hashedpass FROM sys.sql_logins where name='"+$loginname+"'"
			$hashedpass = ($server.databases['tempdb'].ExecuteWithResults($sql)).Tables.hashedpass
			$passtring = ConvertTo-SQLHashString $hashedpass
			$rndpw = $lscript.Substring($lscript.IndexOf('PASSWORD'),$lscript.IndexOf(', SID')-$lscript.IndexOf('PASSWORD'))

			$comment = $lscript.Substring($lscript.IndexOf('/*'),$lscript.IndexOf('*/')-$lscript.IndexOf('/*')+2)
			$lscript = $lscript.Replace($comment,'')
			$lscript = $lscript.Replace($rndpw,"PASSWORD = $passtring HASHED")
			Write-Verbose "creating script for job: $login -> $outfile"
		}
		

		#script login to out file
		$lscript | Out-File -Append -FilePath $outfile

		#if ApplyTo is specified, execute the login creation on the ApplyTo instance
		If($ApplyTo){
			$smotarget = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ApplyTo

			if(!($smotarget.logins.name -contains $loginname)){
				$smotarget.Databases['tempdb'].ExecuteNonQuery($lscript)
				$outmsg='Login ' + $login.name + ' created.'
			}
			else{
				$outmsg='Login ' + $login.name + ' skipped, already exists on target.'
			}
			Write-Verbose $outmsg
		}
	}
	
}