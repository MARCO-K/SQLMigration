  <#
      Author: Marco Kleinert
      Version: 1.0
      Version 
      - 1.0 initial version

      .SYNOPSIS

      This script re-creates all logins saved in a directory.

      .DESCRIPTION

      This scripts uses a given login name or uses all non-builtin logins and retrieves all relavant information to re-create them on another instance.
      Finally the script can apply the created statement directly on a specified server\instance or can save it to a file.

      .PARAMETER ServerInstance

      This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

      .PARAMETER rootpath

      This is the rootpath where all files are saved. Each object type has an own sub folder.

      .EXAMPLE

      Import-Logins -ServerInstance SM10209\S3907 -rootpath D:\temp -verbose
  #>
  #requires -Version 3
function Import-Logins { 
  [cmdletbinding()]
  param([parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$rootpath,
    [string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
  )
 
  begin {  
    $rootpath = Join-Path $rootpath -ChildPath 'logins'
    Write-Verbose "execute all scripts in folder: $rootpath"
  }
  process { 
    try {
      if(Test-Path -Path $rootpath) { 
        $files = Get-ChildItem -path $rootpath -Filter *.sql | Where-Object { $_.Attributes -ne 'Directory'} | sort-object -desc
        foreach ($f in $files) 
        { 
          $out = $outputpath + $f.name.split('.')[0] + '.txt' ; 
          Write-Verbose "execute script: $f"
          invoke-sqlcmd -ServerInstance $ServerInstance -InputFile $f.fullname #| format-table | out-file -filePath $out 
        }
      }
    }
    catch
    {
      Write-Error "Failed to apply configuration to `"$ServerInstance`". $($_.Exception.Message)"
      return $false
    }
  }
  end {
    $message = "Configuration applied to `"$ServerInstance`".";
    return $true
  }
}