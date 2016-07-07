function Get-LoginInfo 
{ 
    param (
        [string] $ServerInstance
        )



    Try # Begin Try for connection to SQL Server and script 
        {

        $SrvConn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $SrvConn.ServerInstance=$ServerInstance
       
        #Load assemblies
       [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
        #create initial SMO object
        $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerInstance
          
        $SrvConn.LoginSecure = $TRUE
        $SqlConnection = New-Object System.Data.SQLClient.SQLConnection("server=$ServerInstance;Integrated Security=sspi;");

                # Use this to execute T-SQL command on server... THIS IS A SECOND CONNECTION!!
        $SqlCommand = New-Object System.Data.SQLClient.SqlCommand; 
        $SqlCommand.Connection = $SqlConnection;        
        
        $CommandSeperator = ';'
        $NewLine = "`r`n"
        $BatchSeperator = 'GO'
        $exclusion = @('DOM1\CSS_CC11SQLFull_DS','DOM1\CSS_CC11SQLAdmin_sub01_DS','DOM1\CSS_CC11SQLAdmin_sub02_DS','DOM1\P12795','sa','DPBackup')

        # Microsoft SMO Scripting Options 
        $ScriptingOptions = New-Object "Microsoft.SqlServer.Management.SMO.ScriptingOptions"; 
        #$ScriptingOptions.TargetServerVersion = [Microsoft.SqlServer.Management.SMO.SqlServerVersion]::$SQLVersion; 
        
        $ScriptingOptions.AllowSystemObjects = $FALSE
        $ScriptingOptions.IncludeDatabaseRoleMemberships = $TRUE
        $ScriptingOptions.ContinueScriptingOnError = $FALSE; # Ignore Scripting errors. It is advisable to set to $FALSE


        # Server Permissions
        'USE [master]'
        $BatchSeperator;

        "-- WINDOWS LOGIN ACCOUNTS AND GROUPS"
        # Server Logins - Integrated Windows Authentication 
        Try 
            {
            $server.Logins | Where-Object {@('WindowsUser','WindowsGroup') -contains $_.LoginType -and $_.IsSystemObject -eq $false -and $_.Name -notlike 'NT *'  -and $_.Name -notlike '##*##' -and $_.Name -notin $exclusion} |% {$_.Script($ScriptingOptions)} |% {$_.ToString()+$CommandSeperator+$NewLine+$BatchSeperator};   
            }
        Catch
            {
            write-verbose 'Windows Login Accounts for this SQL Server cannot be returned at this time'
            Continue
            }
        
        ''
        '-- SQL SERVER LOGIN ACCOUNTS'
        # Server Logins - SQL Server Authentication 
        $SQLAuthLoginsCommand =  "SELECT 'CREATE LOGIN '+ QUOTENAME(sp.[name]) +CHAR(13)+CHAR(10)+
        'WITH PASSWORD = ' + CONVERT(VARCHAR(MAX),LOGINPROPERTY(sp.[name],'passwordhash'),1)+' HASHED,' +CHAR(13)+CHAR(10)+
        'SID = ' + CONVERT(VARCHAR(MAX),CONVERT(VARBINARY(256),sl.[sid]),1) + ',' +CHAR(13)+CHAR(10)+
        'DEFAULT_DATABASE = ' + QUOTENAME(sl.[default_database_name]) + ',' +CHAR(13)+CHAR(10)+
        'DEFAULT_LANGUAGE = ' + QUOTENAME(sl.[default_language_name]) + ',' +CHAR(13)+CHAR(10)+
        'CHECK_EXPIRATION = ' + CASE WHEN sl.[is_expiration_checked] = 1 THEN 'ON, ' ELSE 'OFF, ' END +
        'CHECK_POLICY = ' + CASE WHEN sl.[is_policy_checked] = 1 THEN 'ON' ELSE 'OFF' END 
        FROM sys.sql_logins AS sl INNER JOIN sys.server_principals AS sp 
        ON sl.[principal_id] = sp.[principal_id] 
        WHERE sp.[name] <> 'sa' AND sp.[name] <> 'DPBackup' AND sp.[name] NOT LIKE '##%'"
 
        $SqlCommand.CommandText = $SQLAuthLoginsCommand;   
        Try
            {
            $SqlConnection.Open(); 
            $Reader = $SqlCommand.ExecuteReader(); 
            While ($Reader.Read())
                {$Reader[0]+$CommandSeperator+$NewLine+$BatchSeperator;} 
                $SqlConnection.Close();
            }
        Catch
            {
            Write-Verbose 'SQL Server Login Accounts for this SQL Server cannot be returned at this time'
            Continue
            }
        
        ''
        '-- SQL SERVER ROLE ASSIGNMENTS'
        # Server Roles 
        foreach ($Role in $server.Roles)
        { 
            Try 
                {
                $Role.EnumServerRoleMembers() | Where-Object {$_ -notin $exclusion -and $_ -notlike 'NT *'} |% {"EXEC master..sp_addsrvrolemember @loginame = N'{0}', @rolename = N'{1}'{2}" -f ($_,$Role.Name,$CommandSeperator) ;} 
                }
            Catch
                {
                Write-verbose "SQL Server Role cannot be returned at this time for $($Role.Name)"
                Continue
                }
        }# end For Each Role
        $BatchSeperator

        ''
        '-- SQL SERVER SERVER PERMISSIONS'
        # Server Permissions 
        Try 
            {
            $server.EnumServerPermissions() | Where-Object {@("sa","dbo","information_schema","sys") -notcontains $_.Grantee -and $_.Grantee -notlike "##*" -and $_.Grantee -notlike "NT *"  -and $_.Grantee -notin $exclusion} |% { if ($_.PermissionState -eq "GrantWithGrant") {$wg=" WITH GRANT OPTION "} else {$wg=""};  "{0} {1} TO [{2}] {3}{4}" -f ($_.PermissionState.ToString().Replace("WithGrant","").ToUpper(),$_.PermissionType,$_.Grantee,$wg,$CommandSeperator); };   
            }
        Catch
            {
            write-verbose 'SQL Server server permissions cannot be returned at this time'
            Continue
            }
        $BatchSeperator

        ''
        '-- SQL SERVER SERVER OBJECT PERMISSIONS'
        # Server Object Permissions 
        Try
            {
            $server.EnumObjectPermissions() | Where-Object {@("sa","dbo","information_schema","sys") -notcontains $_.Grantee -and $_.Grantee -notlike "##*" -and $_.Grantee -notlike "NT *"  -and $_.Grantee -notin $exclusion} |% { if ($_.PermissionState -eq "GrantWithGrant"){$wg=" WITH GRANT OPTION "}  else {$wg=""}; "{0} {1} ON {2}::[{3}] TO [{4}] {5}{6}" -f ($_.PermissionState.ToString().Replace("WithGrant","").ToUpper(),$_.PermissionType,$_.ObjectClass.ToString().ToUpper(),$_.ObjectName,$_.Grantee,$wg,$CommandSeperator); };
            }
        Catch
            {
            write-verbos 'SQL Server Object Permissions cannot be returned at this time'
            Continue
            }
        $BatchSeperator
        
        } # End Try for connection to SQL Server and script 

    # Catch for connection to SQL Server and script 
    Catch [system.exception] # Capture exception message, write it out and STOP PROCESSING
        {
        $ErrMSG = $_.Exception.Message
      Write-vrebose "Error Message: $ErrMsg"
        Break
        }

}