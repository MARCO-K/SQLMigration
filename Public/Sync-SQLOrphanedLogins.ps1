function Sync-SQLOrphanedLogins {
  [cmdletbinding()]
  param([parameter(Mandatory=$true,ValueFromPipeline=$True)][string]$ServerInstance
  )
   
  begin {      
      #Load assemblies
      [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
      #create initial SMO object
      $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
   }
   
  Process { 

    foreach ($db in $dbs) {
      $dbname     = $db.Name
      #Get orphaned users.
      # users with login = "" are orphaned users
      $OrphanUser = $db.Users | Where-Object {$_.Login -eq '' -and $_.IsSystemObject -eq $False}
    
      #if there are no orphaned users in a database 
      #move to next database
      if(!$OrphanUser) { 
	  #Write-Verbose "There are no orphan users for database $dbname" 
	  }
      else {
        foreach($user in $OrphanUser)
        {
          #Write-Verbose "Fixing orphan users $user for database $dbname"    
          $username = $user.name
          #get login name with same name as that of orphaned user.
          $login    = $server.logins | where-object {$_.name -eq $user.name  -and $_.isdisabled -eq $False -and $_.IsSystemObject -eq $False -and $_.IsLocked -eq $False}
         
          #if a login doesn't exists; move to next orphaned user
          if(!$login)
          {
            #Write-Verbose "Login with for username $username doesn't exists."
           
          }else
          {
            #fix orphan user.
            $query    = "ALTER USER " +  $username + " WITH LOGIN = " +  $username
            $database = $user.Parent.Name
            #Write-Verbose "Mapping user " + $database + "." + $username + " to " + $username
            #execute the query.
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $database $query
           
          }
        }
      }
    }
  }
  end {}
}
  