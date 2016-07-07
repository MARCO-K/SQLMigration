<#
		Author: Marco Kleinert
		Version: 1.0
		Version 
		- 1.0 initial version

		.SYNOPSIS

		This script extracts a ZIP file from the rootpath to a destination folder.

		.DESCRIPTION

		This script extracts a ZIP file from the rootpath to a destination folder.
    All subfolders and files are included.

		.PARAMETER rootpath

		This is the name of the root path containing a single zip file.

		.PARAMETER destination

		This is the name of the destination path .

		.EXAMPLE

		Expand-Zip -rootpath 'D:\temp\ -destination 'D:\temp\ -verbose
#>
#requires -Version 3
function Expand-Zip {
  param(
    [string]$rootpath,
    [string]$destination
  )

  try {
  if(Test-Path -Path $rootpath) {
    $zipfile = (Get-ChildItem -path $rootpath -Filter *MSSQL*.zip | Where-Object { $_.Attributes -ne 'Directory'} | Sort-Object CreationTime -Descending | Select-Object FullName -First 1).FullName
    #Write-Verbose "Expand ZIP file: $zipfile"
    $shellApplication = new-object -com shell.application
    $zipPackage = $shellApplication.NameSpace($zipfile)
    $destinationFolder = $shellApplication.NameSpace($destination)
    $destinationFolder.CopyHere($zipPackage.Items(), 20)
    #Write-Verbose 'Unzip successful'
  }
    }
  catch { 
  #Write-Verbose 'Unzip failed' 
  }

}