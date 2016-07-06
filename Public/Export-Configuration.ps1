  <#
      Author: Marco Kleinert
      Version: 1.0
      Version 
      - 1.0 initial version

      .SYNOPSIS

      This script creates an output file for server configuration.

      .DESCRIPTION

      This script creates an output file for server configuration.

      .PARAMETER ServerInstance

      This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

      .PARAMETER outputpath

      This is the outputpath where the file will be saved. The file name is create baseed on server/instance name and the date.
      If no path is given the file will be place into "MyDocuments" of the user.

      .EXAMPLE

      Export-Configuration -ServerInstance SM10209\S3907 -outputpath D:\temp -verbose
  #>
  #requires -Version 3    
function Export-Configuration { 
  [cmdletbinding()]
  param([parameter(Mandatory=$true)][string] $ServerInstance,
    [string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
  )
  Begin {      
    #Load assemblies
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
    #create initial SMO object
    $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
    #creating outputpath
    $outputpath = Join-Path $outputpath -ChildPath 'configuration'
    if(!(Test-Path -Path $outputpath )){New-Item -ItemType directory -Path $outputpath}
    #set output filename
    $filename = $ServerInstance.Replace('\','_') + '_' + (Get-Date -Format 'yyyyMMddHHmm')+'-configuration.sql'
    $outfile = Join-Path -Path $outputpath -ChildPath $filename
    Write-Verbose "creating script for configuration -> $outfile"

  }
  
  Process { 
   Try { 
    $props = $server.Configuration.Properties
    write-host $server.Configuration.ShowAdvancedOptions
    foreach($prop in $props) { 
        $dn = $prop[0].DisplayName;
        $cv = $prop[0].ConfigValue; 
        $ls = "exec sp_configure `'$dn`', $cv`r`nGO"
        $ls | Out-File -Append -FilePath $outfile
      }
      $end = "Reconfigure`r`nGO"
      $end | Out-File -Append -FilePath $outfile
      Write-Verbose 'Script for configurationcreated'
      }
    catch { Write-Error "Export configuration reported the following error -  $($_.Exception.Message)"; return $false }
  }
  
  END {
    $message = "Created export of configuration for `"$ServerInstance`".";
    return $true
  }
}