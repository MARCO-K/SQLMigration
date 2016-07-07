<#
		Author: Marco Kleinert
		Version: 1.0
		Version 
		- 1.0 initial version

		.SYNOPSIS

		This script runs all scripts stored in a directory to configure mail.

		.DESCRIPTION

		This script runs all scripts stored in a directory to configure mail. 

		.PARAMETER ServerInstance

		This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

		.PARAMETER rootpath

		This is the rootpath where all files are saved. Each object type has an own sub folder.

		.EXAMPLE

		Import-Configuration -ServerInstance SM10209\S3907 -rootpath D:\temp -verbose
#>
#requires -Version 3
function Import-Mail { 
  [cmdletbinding()]
  param([parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$rootpath,
    [string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
	
  )
  BEGIN {
    $rootpath = Join-Path $rootpath -ChildPath 'mail'
    Write-Verbose "execute all scripts in folder: $rootpath"
    #Load assemblies
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
    #create initial SMO object
    $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
  }
  PROCESS {
    try {
      if($server.Mail.State -ne 'Existing') { 
        if(Test-Path -Path $rootpath) {
          $files = Get-ChildItem -path $rootpath -Filter *.sql | Where-Object { $_.Attributes -ne 'Directory'} | Sort-Object CreationTime -Descending | Select-Object FullName -First 1
          foreach ($f in $files) 
          { 
            $server.Configuration.ShowAdvancedOptions.ConfigValue = $true
            $server.Configuration.Alter()
            #$out = $outputpath + $f.name.split('.')[0] + '.txt' 
            Write-Verbose "execute script: $f"
            invoke-sqlcmd -ServerInstance $ServerInstance -InputFile $f.FullNAme #| format-table | out-file -filePath $outputpath 
          }
        }
      }
      else { Write-Verbose 'Database mail already configured' }
    }
    catch
        {
          Write-Error "Failed to apply  mail configuration to `"$ServerInstance`". $($_.Exception.Message)"
          return $false
        }
  }
  end {
    if($server.Configuration.DatabaseMailEnabled.ConfigValue -ne 1) {   
       $server.Configuration.DatabaseMailEnabled.ConfigValue = 1
       $server.Configuration.Alter()
      }
    if($server.JobServer.AgentMailType -ne 'DatabaseMail') {
      $profileName = $server.Mail.Profiles.name
      $server.JobServer.AgentMailType = 'DatabaseMail'
      $server.JobServer.DatabaseMailProfile = $profileName
      $server.JobServer.Alter()
    }
    $message = "Configuration applied to `"$ServerInstance`".";
    return $true
  }
}