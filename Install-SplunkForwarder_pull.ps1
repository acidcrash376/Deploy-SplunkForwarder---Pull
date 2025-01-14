#Requires -RunAsAdministrator
<#
.SYNOPSIS
  A script to install Splunk Universal Forwarder and Sysmon

.DESCRIPTION
  This script is to be deployed by GPO and install both Splunk Universal Forwarder and Sysmon.
  By default, your Splunk Forwarder installer should be named splunkforwarder.msi. You will require a directory in root of C:\
  called Share. Place the splunkforwarder.msi, sysmon64.exe sysmonconfig-export.xml, inputs.conf and outputs.conf in c:\Share
  This path can be changed by the $fileshare variable.

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0.4.RC1
  Author:         Acidcrash376
  Creation Date:  23/06/2021
  Last Update:	  30/06/2021
  Purpose/Change: Release Candidate 1
  Web:            https://github.com/acidcrash376/Install-SplunkForwarder-Pull

.PARAMETER Verbosemode 
  Not Required
  No value required. Enables Verbose output for the script.

.EXAMPLE
  ./Install-SplunkForwarder.ps1

.EXAMPLE
  ./Install-SplunkForwarder.ps1 -Verbosemode


.TODO
  - Allow alternate filenames
#>

Param([switch] $verbosemode )
if ($verbosemode -eq $true)
{
    $VerbosePreference="Continue"
    Write-Verbose "Verbose mode is ON"
} else {
}

########################
# Edit these variables #
########################
$ErrorLogfile = "\\dc\Tools\$(gc env:computername)\Error.log"             # Path for Error Log, edit the path
$InstallLogfile = "\\dc\Tools\$(gc env:computername)\Install.log"         # Path for Install Log, edit the path
$fileshare = "\\dc\Tools\"                                                # Path for fileshare, edit the path
$SplunkU = "splunk"                                                       # Define the local Splunk management user
$SplunkP = "password"                                                     # Define the local Splunk management user password
$rindex = "192.168.59.201:9997"                                           # Define the Splunk indexer IP and port
#########################
# Don't edit after here #
#########################


Function Write-ErrorLogHead
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $ErrorLogfile -value $logstring
}

Function Write-InstallLogHead
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $InstallLogfile -value $logstring
}

Function Write-ErrorLog
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $ErrorLogfile -value $logstring
}

Function Write-InstallLog
{
   Param ([string]$logstring)
   New-Item -Path $fileshare -Name "$(gc env:computername)" -ItemType "directory" -Force | Out-Null
   Add-content $InstallLogfile -value $logstring
}

Function Get-DTG
{
    $(((Get-Date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fffZ"))                       # Date Time Group suffix for logging, YYYY-MM-DD HH:mm:ss Zulu time
}

Function Test-SplunkForwarder () 
{
	Write-InstallLog -logstring "$(Get-DTG) - [Function: Test-SplunkForwarder]"                  #                                   
    $software = "UniversalForwarder";                                                            # Defines the variable for Splunk Universal Forwarder
	$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -eq $software }) -ne $null  # Check the registry for the existance of Splunk Forwarder
    Write-Verbose "Testing to see if Splunk Universal Forwarder is installed"                    # If Verbose is enabled, print to console status

	If(-Not $installed) {                                                                        # If Splunk Forwarder is not installed...
        Write-Verbose "Splunk is not installed"                                                  # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - Splunk Universal Forwarder is not currently installed" # Log it
        Install-SplunkForwarder                                                                  # Call the Install-SplunkForwarder function
	} else {                                                                                     # If Splunk Forwarder is installed... 
		Write-Verbose "Splunk is installed"                                                      # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - Splunk Universal Forwarder is installed"       # Log it
	}
}

Function Test-SMBConnection () 
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Test-SMBConnection]"                    # Log it
	$test = Test-Path -Path $fileshare                                                           # Test whether the fileshare can be reached
	if($test) {
        Write-Verbose "$(fileshare) can be reached"                                              # If Verbose is enabled, print to console status
        Write-InstallLog -logstring "$(Get-DTG) - $fileshare successfully reached"               # Log it successfully being able to reach the fileshare
	} else {
        Write-Verbose "$(fileshare) could not be reached"                                        # If Verbose is enabled, print to console status
		Write-ErrorLog -logstring "$(Get-DTG) - $fileshare fileshare could not be reached"       # Log it failing in the Error log and exit the script
        exit
	}
}

Function Check-ConfHash ()
{                                                           
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Check-ConfHash]"
    $inputsconf = $fileshare+'inputs.conf'                                                       # Define the variable for the fileshare path to inputs.conf
    $srvInputsHash = Get-FileHash -Path $inputsconf -Algorithm SHA256                            # SHA256 Hash the inputs.conf on the 
    Write-InstallLog -logstring "$(Get-DTG) - $srvInputsHash"                                    # Log the hash

    $Outputsconf = $fileshare+'Outputs.conf'                                                     # Define the variable for the fileshare path to outouts.conf
    $srvOutputsHash = Get-FileHash -Path $Outputsconf -Algorithm SHA256                          # SHA256 Hash the outputs.conf on the fileshare 
    Write-InstallLog -logstring "$(Get-DTG) - $srvOutputsHash"                                   # Log the hash

    $LocalInputsConf = "C:\Program Files\SplunkUniversalForwarder\etc\apps\SplunkUniversalForwarder\local\inputs.conf"  # Define the variable for the local path to inputs.conf
    $LocalOutputsConf = "C:\Program Files\SplunkUniversalForwarder\etc\apps\SplunkUniversalForwarder\local\outputs.conf"# Define the variable for the local path to outputs.conf

    $testlocalinputsconf = Test-Path $LocalInputsConf                                            # Test the path of the local inputs.conf for the if statement:
                                                                                                 # If present, do the hashes match: Yes, move on. No, replace with file from server
                                                                                                 # If not present, copy from file server
                                                                                                  
    $testlocaloutputsconf = Test-Path $LocalOutputsConf                                          # Test the path of the local outputs.conf for the if statement:
                                                                                                 # If present, do the hashes match: Yes, move on. No, replace with file from server
                                                                                                 # If not present, copy from file server    

    $srvInputsHashsha256 = ${srvInputsHash}.Hash                                                 # Define the variable for the server inputs.conf hash
    $srvOutputshashsha256 = ${srvOutputsHash}.Hash                                               # Define the variable for the server outputs.conf hash

    If($testlocalinputsconf)                                                                     # If the test of the local inputs.conf is true...
    {
        
        Write-Verbose "Inputs.conf exists"
        Write-InstallLog -logstring "$(Get-DTG) - Inputs.conf exists"                            # Log it
        $localInputsHash = Get-FileHash -Path $LocalInputsConf -Algorithm SHA256                 # Hash the local inputs.conf and define as a variable for comparing
        Write-InstallLog -logstring "$(Get-DTG) - $localinputshash"                              # Log it

        If($srvInputsHashsha256 -eq ${localInputsHash}.hash)                                     # If inputs.conf hashes match
        {
            Write-Verbose "Inputs.conf match, no action required"
            Write-InstallLog -logstring "$(Get-DTG) - Inputs.conf match, no action required"     # Log it, no action required

        } else {
            
            Write-Verbose "Inputs.conf do not match, replacing the config"
            Write-InstallLog -logstring "$(Get-DTG) - Inputs.conf do not match, replacing the config"  # If they don't match, log it
            Copy-Item $inputsconf -Destination $LocalInputsConf -Force                           # Copy the file from the file server and overwrite the local version

        }
    } else {
        
        Write-Verbose "Inputs.conf is not present, copying over"
        Write-InstallLog -logstring "$(Get-DTG) - Inputs config does not exist"                  # If inputs.conf is not present, log it
        Copy-Item $inputsconf -Destination $LocalInputsConf -Force                               # Copy the inputs.conf from the fileserver to the local machine
        Write-InstallLog -logstring "$(Get-DTG) - inputs.conf copied from fileserver"            # Log it
    
    }

    If($testlocalOutputsconf)                                                                    # If the test of the local inputs.conf is true...
    {
        
        Write-Verbose "outputs.conf exists"
        Write-InstallLog -logstring "$(Get-DTG) - Outputs.conf exists"                           # Log it
        $localInputsHash = Get-FileHash -Path $LocalOutputsConf -Algorithm SHA256                # Hash the local Outputs.conf and define as a variable for comparing
        Write-InstallLog -logstring "$(Get-DTG) - $localOutputshash"                             # Log it

        If($srvOutputsHashsha256 -eq ${localOutputsHash}.hash)                                   # If Outputs.conf hashes match
        {
            Write-Verbose "Outputs.conf match, no action required"
            Write-InstallLog -logstring "$(Get-DTG) - Outputs.conf match, no action required"    # Log it, no action required

        } else {
            
            Write-Verbose "Outputs.conf do not match, replacing the config"
            Write-InstallLog -logstring "$(Get-DTG) - Outputs.conf do not match, replacing the config" # If they don't match, log it
            Copy-Item $Outputsconf -Destination $LocalOutputsConf -Force                         # Copy the file from the file server and overwrite the local version

        }
    } else {
        
        Write-Verbose "Outputs.conf does not exist, copying over"
        Write-InstallLog -logstring "$(Get-DTG) - Outputs.conf does not exist"                   # If Outputs.conf is not present, log it
        Copy-Item $Outputsconf -Destination $LocalOutputsConf -Force                             # Copy the Outputs.conf from the fileserver to the local machine
        Write-InstallLog -logstring "$(Get-DTG) - Outputs.conf copied from fileserver"           # Log it
    
    }
}

Function Install-SplunkForwarder ()
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Install-SplunkForwarder]"
    $splunkmsi = $fileshare+"splunkforwarder.msi"                                                # Concatanate the fileshare and the filename for the Installer
    $msitest = Test-Path -Path $splunkmsi                                                        # Test the patch exists
    if($msitest)                                                                                 # If yes, install splunk with the following values
    {
        Start-Process -FilePath $splunkmsi –Wait -Verbose –ArgumentList "AGREETOLICENSE=yes SPLUNKUSERNAME=`"$($splunkU)`" SPLUNKPASSWORD=`"$($splunkP)`" RECEIVING_INDEXER=`"$($rindex)`" WINEVENTLOG_APP_ENABLE=1 WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 WINEVENTLOG_FWD_ENABLE=1 WINEVENTLOG_SET_ENABLE=1 ENABLEADMON=1 PERFMON=network /quiet"
        Write-InstallLog -logstring "$(Get-DTG) - Splunk Forwarder has been installed"
        Write-Verbose "Splunk Forwarder has been installed"
    } else {
        Write-ErrorLog -logstring "$(Get-DTG) - Splunk Universal Forwarder msi is not found."    # If no, exit the script
        Write-Verbose "Splunk Forwarder install msi not found, exiting..."
        exit
    }
}

Function Install-Sysmon ()
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Install-Sysmon]"                        # Log it
    
    $sysmonexe = $fileshare+"sysmon64.exe"                                                       # Concatanate the fileshare and the filename for Sysmon
    $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                           # Concatanate the fileshare and the filename for Sysmon Config
    
    $sysmontest = Test-Path -Path $sysmonexe                                                     # Tests whether the Sysmon exe exists
    $sysmonconftest = Test-Path -Path $sysmonconf                                                # Tests whether the Sysmon conf exists
    
    If(($sysmontest) -and ($sysmonconftest))                                                     # If both the exe and the conf exist
    { 
        if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null)                              # Check if sysmon is already running, if no:
        { 
            New-Item -Path $env:ProgramFiles -Name Sysmon -ItemType Directory -Force | Out-Null  # Create the system directory in c:\Program Files
            $sysmon = $fileshare+"sysmon64.exe"                                                  # Define variable for remote path to the executable
            $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                   # Define variable for remote path to the config
            Copy-Item $sysmon -Destination $env:ProgramFiles\Sysmon -Force                       # Copy the executable from the share
            Copy-Item $sysmonconf -Destination $env:ProgramFiles\Sysmon\ -Force                  # Copy the config from the share
            Write-Verbose "Sysmon exe and conf has been copied over"
            & $env:ProgramFiles\Sysmon\sysmon64.exe -i $env:ProgramFiles\Sysmon\sysmonconfig-export.xml -accepteula > $null  # Run Sysmon with the specified config, accepting the EULA and outputing to $null
            if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null)                          # Checks if Sysmon started correctly
            { 
                Write-Verbose "Sysmon Not Running"
                Write-ErrorLog -logstring "$(Get-DTG) - Sysmon failed to start"                  # Logs it having failed
            } else {
                Write-Verbose "Sysmon is running"
                Write-InstallLog "$(Get-DTG) - Sysmon running"                                   # Logs it running successfully
            } 
        } else { 
            & $env:ProgramFiles\Sysmon\sysmon64.exe -u > $null                                   # Checked if sysmon was running and yes
            Write-Verbose "Stopping Sysmon"
            $sysmon = $fileshare+"sysmon64.exe"                                                  # Defines variable for remote path to the executable
            $sysmonconf = $fileshare+"sysmonconfig-export.xml"                                   # Defines variable for remote path to the config
            Copy-Item $sysmon -Destination $env:ProgramFiles\Sysmon -Force                       # Copy the executable from the share
            Copy-Item $sysmonconf -Destination $env:ProgramFiles\Sysmon\ -Force                  # Copy the config from the share
            Write-Verbose "Copying and overwriting Sysmon exe and conf"
            & $env:ProgramFiles\Sysmon\sysmon64.exe -i $env:ProgramFiles\Sysmon\sysmonconfig-export.xml -accepteula > $null  # Run Sysmon with the specified config, accepting the EULA and outputting t $null
            if((get-process "sysmon64" -ea SilentlyContinue) -eq $Null)                          # Checks if Sysmon started correctly
            { 
                Write-Verbose "Sysmon Not Running"                                  
                Write-ErrorLog -logstring "$(Get-DTG) - Sysmon failed to start"                  # Logs it having failed
            } else {
                Write-Verbose "Sysmon is running"
                Write-InstallLog "$(Get-DTG) - Sysmon running"                                   # Logs it running successfully
            }
        }
    } else {
        Write-Verbose "Sysmon and/or Sysmon config not found"
        Write-ErrorLog -logstring "$(Get-DTG) - Sysmon64 and sysmonconfig not found"             # Sysmon and/or Sysmon config not found, exiting script
        exit
    }
     
   
}

Function Restart-Splunk ()
{
    Write-InstallLog -logstring "$(Get-DTG) - [Function: Restart-Splunk]"
    #Stop-Service SplunkForwarder                                                                # Stop-Service causes issues, using alternate method below
    $testsplunk = Get-Service SplunkForwarder                                                    # Check if Splunk is running
    If(($testsplunk).Status -eq 'Running')                                                       # If yes...
    {
        #Restart-Service SplunkForwarder                                                         # Restart-Service causes issues, using alternate method
        & "C:\program files\splunkuniversalforwarder\bin\splunk.exe" "restart" > $null           # Restart Splunk service
        #Start-Service SplunkForwarder
        $testsplunk1 = Get-Service SplunkForwarder                                               # Check whether Splunk service has restarted successfully
        if(($testsplunk1).Status -eq 'Running')
        {
            Write-Verbose "Splunk has restarted successfully"
            Write-InstallLog -logstring "$(Get-DTG) - Splunk Forwarder has been restarted successfully"
        } else {
            Write-Verbose "Splunk has failed to restart successfully"
            Write-ErrorLog -logstring "$(Get-DTG) - Splunk Universal Forwarder could not be started" # Splunk has failed to start, log it and exit script
            exit
        }
    } else {
        & "C:\program files\splunkuniversalforwarder\bin\splunk.exe" "start" > $null             # Splunk was not running, starting it now
        $testsplunk2 = Get-Service SplunkForwarder                                               # Checks if Splunk has started successfully
        if(($testsplunk2).Status -eq 'Running')
        {
            Write-Verbose "Splunk has started successfully"
            Write-InstallLog -logstring "$(Get-DTG) - Splunk Forwarder has been restarted successfully"
        } else {
            Write-Verbose "Splunk has failed to start"
            Write-ErrorLog -logstring "$(Get-DTG) - Splunk Universal Forwarder could not be started" # Splunk has failed to start, log it and exit script
            exit
        }
    }
}

Write-InstallLogHead -logstring "------------------------------------------------------------"
Write-InstallLogHead -logstring "|Splunk Universal Forwarder installation script Install log|"
Write-InstallLogHead -logstring "------------------------------------------------------------`n"
Write-ErrorLogHead -logstring "----------------------------------------------------------"
Write-ErrorLogHead -logstring "|Splunk Universal Forwarder installation script Error log|"
Write-ErrorLogHead -logstring "----------------------------------------------------------`n"

Write-Host "Installing Splunk Universal Forwarder and Sysmon.`nThis will take a couple of minutes."
Test-SplunkForwarder
Test-SMBConnection
Check-ConfHash
Install-Sysmon
Restart-Splunk
Write-Host "Splunk Universal Forwarder and Sysmon have been installed"
