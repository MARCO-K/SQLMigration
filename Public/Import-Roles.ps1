	<#
			Author: Marco Kleinert
			Version: 1.0
			Version 
			- 1.0 initial version

			.SYNOPSIS

			This script re-creates all role memberships from files saved in a directory.

			.DESCRIPTION

			This script re-creates all role memberships from files saved in a directory.
			.PARAMETER ServerInstance

			This is the name of the source instance. It's a mandatory parameter beause it is needed to retrieve the data.

			.PARAMETER rootpath

			This is the rootpath where all files are saved. Each object type has an own sub folder.

			.EXAMPLE

			Import-Roles -ServerInstance SM10209\S3907 -rootpath D:\temp -verbose
	#>
	#requires -Version 3
function Import-Roles { 
  [cmdletbinding()]
  param([parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance,
    [parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$rootpath,
    [string] $outputpath=([Environment]::GetFolderPath('MyDocuments'))
  )
  
  begin {   
    $rootpath = Join-Path $rootpath -ChildPath 'roles'
    Write-Verbose "execute all scripts in folder: $rootpath"
  }
  process { 
    try{
      if(Test-Path -Path $rootpath) { 
        $files = Get-ChildItem -path $rootpath -Filter *.sql | Where-Object { $_.Attributes -ne 'Directory'} | sort-object -desc
        foreach ($f in $files) 
        { 
          $out = $outputpath + $f.name.split('.')[0] + '.txt' ; 
          invoke-sqlcmd -ServerInstance $ServerInstance -InputFile $f.fullname #| format-table | out-file -filePath $outputpath
        }
      }
    }
    catch
      {
        Write-Error "Failed to apply roles to `"$ServerInstance`". $($_.Exception.Message)"
        return $false
      }
  }
  end {
    $message = "Roles memberships applied to `"$ServerInstance`".";
    return $true
  }
}