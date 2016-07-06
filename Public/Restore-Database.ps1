<#
    Author: Marco Kleinert
    Version: 1.0
    Version History:

    - 1.0 inital creation
    - 1.2 support more than one datafile

    .SYNOPSIS

    This script will restore one database with multiple data and log files.

    .DESCRIPTION

    The restore script  is restoring a specific database to a default file locations. 

    .PARAMETER $ServerInstance

    This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

    .PARAMETER $dbname

    The parameter can be empty. In this case the database name will be retrieved from the backup media header.

    .PARAMETER ServerInstance

    This the directory where all backup filesare restored. Only the name to the rootpath is required.
    The backup file must start with the datbasename. If more than one file for a database exists the newest version is used.

    .EXAMPLE

    Restore-Database -verbose -serverinstance sm10209\s3907 -backupDirectory 'D:\Microsoft SQL Server\S3907\Instance\MSSQL11.S3907\MSSQL\Backup\' -dbname test -replace

#>
#requires -Version 3
function Restore-Database { 
  [cmdletbinding()]
  param
  ([parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string[]]$dbname,
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$rootpath,
    [switch]$replace
  )


  BEGIN {
    $rootpath = Join-Path $rootpath -ChildPath 'backups'
    Write-Verbose "Restore datbases in folder: $rootpath"
    #Load assemblies
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended')
    #create initial SMO object
    $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
    
    # Get the default file and log locations
    $fileloc = $server.Settings.DefaultFile
    $logloc = $server.Settings.DefaultLog
    # (If DefaultFile and DefaultLog are empty, use the MasterDBPath and MasterDBLogPath values)
    if ($fileloc.Length -eq 0) { $fileloc = $server.Information.MasterDBPath }
    if ($logloc.Length -eq 0) { $logloc = $server.Information.MasterDBLogPath }
  
    #select newest backup file from root\backup directory
    $backupDirectory = (Get-ChildItem -Recurse $rootpath | Where-Object {$_.Name -match "$dbname.*" } | Sort-Object CreationTime -Descending | Select-Object -expand Fullname -First 1)
  } 
  
  Process { 
    $restore = New-Object Microsoft.SqlServer.Management.Smo.Restore
    $device = New-Object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $backupDirectory, 'FILE'
    $restore.Devices.Add($device)

    if(!$dbname) {
      # Get the details from the backup device for the database name and output that
      $smoRestoreDetails = $restore.ReadBackupHeader($server)
      $databaseName = $smoRestoreDetails.Rows[0]['DatabaseName']
      
    }
    else { $databaseName =$dbname }
    
    if($server.Databases.Contains($databaseName) -and $replace -ne $true) { Write-Host "Database $databaseName does already exist and replace parameter is set to $replace" -ForegroundColor Red }
    else { 
      write-verbose "Restoring database: $databaseName"
      try { $filelist = @{}; $filelist = $restore.ReadFileList($server) }
      catch {  
        $exception = $_.Exception
        Write-Host "$exception. `n`nDoes the SQL Server service account have acccess to the backup location?" -ForegroundColor Red
      }
    
      $filestructure = @{}; $datastructure = @{}; $logstructure = @{}
      $logfiles = $filelist | Where-Object {$_.Type -eq 'L'}
      $datafiles = $filelist | Where-Object {$_.Type -ne 'L'}

      # Data Files (if db has filestreams, make sure server has them enabled)
      foreach ($df in $datafiles) {
      $datastructure = @{}
        $datastructure.physical = $df.PhysicalName
        $datastructure.extension = [System.IO.Path]::GetExtension($datastructure.physical)
        $datastructure.logical = $df.LogicalName
        $filestructure.add($df.LogicalName,$datastructure)
      }

      # Log Files
      foreach ($lf in $logfiles) {
        $logstructure = @{}
        $logstructure.physical = $lf.PhysicalName
        $logstructure.extension = [System.IO.Path]::GetExtension($logstructure.physical)
        $logstructure.logical = $lf.LogicalName
        $filestructure.add($lf.LogicalName,$logstructure)
      }

      # Make sure big restores don't timeout
      $server.ConnectionContext.StatementTimeout = 0
      # This restores to the same structure found within the .bak file but re-locate files to default location on target
       foreach($elem in $filestructure.values) {
         write-verbose "Relocate file: $($elem.logical + $elem.extension) to $($elem.physical)"
         $movefile = New-Object 'Microsoft.SqlServer.Management.Smo.RelocateFile' 
         $movefile.LogicalFileName = $($elem.logical)
         $movefile.PhysicalFileName = join-path -path $fileloc -ChildPath ($elem.logical + $elem.extension)
         #$movefile.PhysicalFileName = $file.physical
         $null = $restore.RelocateFiles.Add($movefile)
       }

      Write-verbose "Restoring $databaseName to $ServerInstance"

      try {
	
        if($replace) {$restore.ReplaceDatabase = $true}
        $restore.Database = $databaseName
        $restore.Action = 'Database'
        $restore.NoRecovery = $false
	
        $restore.sqlrestore($ServerInstance)
        
        Write-verbose 'Restore complete!'
      } catch {
        $exception = $_.Exception.InnerException; Write-Host $exception -ForegroundColor Red
      }
    }
  }
  end {
      $message = "Database `"$databaseName`" resotred on `"$ServerInstance`".";
      return $true
    }
	
}