<#
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

    Restore-SQLDatabases -serverinstance server\instance -backupFile 'D:\MSSQL\Backup\' -dbname test -replace

#>
#requires -Version 3
function Restore-SQLDatabases 
{ 
  [cmdletbinding()]
  param
  ([parameter(Mandatory,ValueFromPipeline = $true)][string]$ServerInstance,
    [parameter(Mandatory,ValueFromPipeline = $true)][string[]]$dbname,
    [parameter(ValueFromPipeline = $true)][string]$todbname = '',
    [parameter(ValueFromPipeline = $true)][string]$rootpath,
    [switch]$replace
  )


  BEGIN {

    #Load assemblies
    $null = [reflection.assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended')
    Write-Log -LogLevel INFO -Message "Restore database started on `"$ServerInstance`"."
    
  

  } 
  
  Process { 
    #create initial SMO object
    $server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $ServerInstance
    #validate backup directory
    if(!($rootpath)) 
    {
      $rootpath = $server.BackupDirectory
    }
    else 
    {
      $rootpath = Join-Path -Path $rootpath -ChildPath 'backups' 
    }
      
      
    # Get the default file and log locations
    $fileloc = $server.Settings.DefaultFile
    $logloc = $server.Settings.DefaultLog
    # (If DefaultFile and DefaultLog are empty, use the MasterDBPath and MasterDBLogPath values)
    if ($fileloc.Length -eq 0) 
    {
      $fileloc = $server.Information.MasterDBPath
    }
    if ($logloc.Length -eq 0) 
    {
      $logloc = $server.Information.MasterDBLogPath
    }
      
    #
    if($dbname) 
    {
      $database = $server.Databases[$dbname]
      $db_name = $database.Name
    }
    else 
    {
      Write-Log -LogLevel ERROR -Message "Database $dbname does not exist."
      break
    }
       
    $backupFile = (Get-ChildItem -Recurse -Path $rootpath -Filter '*.bak' |
      Where-Object -FilterScript {
        $_.Name -match "^$db_name_`$*"
      } |
      Sort-Object -Property CreationTime -Descending |
    Select-Object -ExpandProperty Fullname -First 1)
       
    if( ($backupFile | Measure-Object).Count -gt 1) 
    {
      Write-Log -LogLevel ERROR -Message "More than 1 backup file available for  $dbname."
      break
    }
 
         
    $restore = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Restore
    $device  = New-Object -TypeName Microsoft.SqlServer.Management.Smo.BackupDeviceItem -ArgumentList $backupFile, 'FILE'
    $restore.Devices.Add($device)   
    $BackupHeader = $restore.ReadBackupHeader($server)

    #check if dbname match BackupHeader info
    if($db_name  -ne $BackupHeader.DatabaseName) 
    {
      Write-Log -LogLevel ERROR -Message "Database name for $dbname does not match the BackupHeader."
      break
    }

    #check if enough free space is available
    if($BackupHeader.BackupSize -ge (Get-PSDrive (Get-Item $logloc).PSDrive.Name).Free )
    { Write-Log -LogLevel ERROR -Message  'Database size is greater than available free space on disk.'
    break
    }
    
    
    if(($server.Databases.Contains($db_name) -and $replace -ne $true) -xor $todbname.Length -gt 0 )
    {
      Write-Host -Object (($server.Databases.Contains($db_name) -and $replace -ne $true) -xor $todbname.Length -gt 0 )
      Write-Log -LogLevel ERROR -Message  "Database $db_name does already exist and replace parameter is set to $replace"
    }
    else 
    { 
      try 
      {
        $filelist = @{}
        $filelist = $restore.ReadFileList($server)
      }
      catch 
      {  
        $exception = $_.Exception
        Write-Log -LogLevel ERROR  -Message 'Cannot access backupfile'
      }
    
      $filestructure = @{}
      $datastructure = @{}
      $logstructure = @{}
      $logfiles = $filelist | Where-Object -FilterScript {
        $_.Type -eq 'L'
      }
      $datafiles = $filelist | Where-Object -FilterScript {
        $_.Type -ne 'L'
      }

      # Data Files (if db has filestreams, make sure server has them enabled)
      foreach ($df in $datafiles) 
      {
        $datastructure = @{}
        $datastructure.physical = $df.PhysicalName
        $datastructure.extension = [IO.Path]::GetExtension($datastructure.physical)
        $datastructure.logical = $df.LogicalName
        $filestructure.add($df.LogicalName,$datastructure)
      }

      # Log Files
      foreach ($lf in $logfiles) 
      {
        $logstructure = @{}
        $logstructure.physical = $lf.PhysicalName
        $logstructure.extension = [IO.Path]::GetExtension($logstructure.physical)
        $logstructure.logical = $lf.LogicalName
        $filestructure.add($lf.LogicalName,$logstructure)
      }
      
      # Make sure big restores don't timeout
      $server.ConnectionContext.StatementTimeout = 0
      # This restores to the same structure found within the .bak file but re-locate files to default location on target
      foreach($elem in $filestructure.values) 
      {
        if($todbname)
        {
          $filename = $elem.logical -replace $db_name, $todbname
        }

        $movefile = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.RelocateFile' 
        $movefile.LogicalFileName = $($elem.logical)
        $movefile.PhysicalFileName = Join-Path -Path $fileloc -ChildPath ($filename + $elem.extension)
        Write-Log -LogLevel INFO -Message  "Relocate file: $($movefile.LogicalFileName)  to $($movefile.PhysicalFileName)"
        $null = $restore.RelocateFiles.Add($movefile)
      }
      
      try 
      {
        if($replace) 
        {
          $restore.ReplaceDatabase = $true
        }
        if($todbname) 
        {
          $restore.Database = $todbname 
        }
        else 
        {
          $restore.Database = $db_name
        }
        $restore.Action = 'Database'
        $restore.NoRecovery = $false
	
        $restore.sqlrestore($ServerInstance)
        
        Write-Log -LogLevel INFO -Message  "Restore database: $($restore.Database) completed."
      }
      catch
      {
        Write-Log -LogLevel ERROR -Message $Error[0]
        $err = $_.Exception
        while ( $err.InnerException ) 
        {
          $err = $err.InnerException
          Write-Log -LogLevel ERROR -Message $err.Message
        }
      }
    }
  }
  end {
    Write-Log -LogLevel INFO -Message "Restore database completed on `"$ServerInstance`"."
  }
}
