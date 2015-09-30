Function Salt-Connect {

<#

.Synopsis

Salt-Connect creates connection to Salt master in the specified environment.

.Description

Salt-Connect creates authenticated connection to Salt API in the given environment so we can start executing commands against Salt minions or master.
It will change your PowerShell prompt to denote salt master you are connected to.

.Parameter saltMaster

Name of the Salt master you are trying to connect to.

.Parameter Loud

Formats error output for easy reading. Use it of you are working interactively, skip if you need to capture error output in your script.

.Example

Salt-Connect saltStaging

Connects to saltStaging master. This is equivalent of the command Salt-Connect -M saltStaging or Salt-Connect -saltMaster saltStaging

.Example

Salt-Connect saltStaging -Loud

Connects to saltStaging master and displays formatted error output in case master is not responding.

.Example

$master = saltStaging ; $master | Salt-Connect

Connects to saltStaging master by using value from pipeline.

#>

[CmdletBinding(SupportsShouldProcess = $false, DefaultParameterSetname = "connect", ConfirmImpact="Medium")] 

param (

	[Parameter(ParameterSetName = "connect", Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $True,
				ValueFromPipeline = $True)]
	[ValidatePattern("<salt master name in Staging|salt master name in UAT|salt master name in Production>")]
    [Alias("M")]
	[string]
    $saltMaster, 
	
	[Parameter(ParameterSetName = "connect", Mandatory = $false, Position = 1)]
	[switch]
    $Loud

)

	$ErrorActionPreference = "Stop"
	
	#Error handling
	trap {
	
		$_.Exception.Message

		If ( $_.Exception.Message -match "500|connect to the remote server" ) {

			$Return = New-Object PSObject -Property ([ordered]@{ "Error" = "Salt API Down" ; "Result" = $False })
			
			If ( $Loud ) {
				
				return $Return | ft -AutoSize
			}
			
			Else {
			
				return $Return
			}
		}
		
		continue
	}

	Switch -regex ( $saltMaster ) {

        "<salt master name in Staging>" { 
		
			$global:Environment = "Staging" 
			$global:Color = "Yellow"	
		}

        "<salt master name in UAT>" { 
		
			$global:Environment = "UAT" 
			$global:Color = "Blue"		
		}

        "<salt master name in Production>" { 
		
			$global:Environment = "Production" 	
			$global:Color = "Red"
		}
        
    }
			
	$global:saltMaster_Url = "http://" + $saltMaster + ":8000"
		
	$global:urlLogin = $saltMaster_Url + "/login"
    $global:url = $saltMaster_Url + "/minions"
	
    # Getting token for authentication
    $json = "{`"username`": `"<username>`", `"password`": `"<password>`", `"eauth`": `"pam`"}"
    
	$ExperationTime = (Get-Date).Addhours(9)
	
	$Token = (Invoke-RestMethod -Uri $urlLogin -Method Post -Body $json -ContentType "application/json").return.token
	
	$global:Token_Obj = New-Object PSObject -Property @{ "Token" = $Token ; "Experation" = [datetime]$ExperationTime }
	
	$global:saltMaster_Prompt = $saltMaster
			
	Function global:Prompt {
			
		Write-Host "PS [$saltMaster_Prompt] $PWD>" -NoNewline -ForegroundColor $Color
		
		return " "
		
	}
	
	$Token = $null

}

Function Salt {

<#

.Synopsis

Salt allows commands execution in the same format as accepted by salt command on Linux. 

.Description

Salt executes given salt commands and output jid number that can be used to get job result. It can work together with salt-run command (please see help for salt-run to get some examples).

Salt-Connect must be executed first to get authorized connection to salt master. Otherwise you will get an error.

.Parameter G

Grains glob.

.Parameter Grain_PCRE

Grains PCRE.

.Parameter I

Pillar glob.

.Parameter E

PCRE

.Parameter L

List

.Parameter S

Subnet/IP address

.Parameter N

Node group

.Parameter C

Compound

.Example

salt "*" test.ping

Executes test.ping command on all salt minion.

.Example

Salt –G "application:test" cmd.run "ifconfig" | salt-run -Loud
Executes ifocnfig command on salt minion with the grain application:test and returns job result in the formatted form. 

.Example

Salt -Grain_PCRE 'osrelease:6.*' grains.item osrelease  | Salt-Run -Loud

Gets OS version for all minions that have grain osrelease matching 6.* expression. 

.Example

Salt -C 'P@osrelease:6.*' grains.item osrelease  | Salt-Run –Loud

Gets OS version for all minions that have grain osrelease matching 6.* expression (by using compound matcher)

#>


[CmdletBinding(SupportsShouldProcess = $false, DefaultParameterSetname = "post", ConfirmImpact="Medium")] 

param (

	[Parameter(ParameterSetName = "grains_glob", Mandatory = $true, Position = 0)]
	[switch]
	[Alias("grain")]
    $G,
	
	[Parameter(ParameterSetName = "grains_pcre", Mandatory = $true, Position = 0)]
	[switch]
	$grain_pcre,
	
	[Parameter(ParameterSetName = "pillar", Mandatory = $true, Position = 0)]
	[switch]
	[Alias("pillar")]
    $I,

    [Parameter(ParameterSetName = "pcre", Mandatory = $true, Position = 0)]
	[switch]
	[Alias("pcre")]
    $E,

    [Parameter(ParameterSetName = "list", Mandatory = $true, Position = 0)]
	[switch]
	[Alias("list")]
    $L,

    [Parameter(ParameterSetName = "ipcidr", Mandatory = $true, Position = 0)]
	[switch]
	[Alias("ipcidr")]
    $S,
	
	[Parameter(ParameterSetName = "nodegroup", Mandatory = $true, Position = 0)]
	[switch]
	[Alias("nodegroup")]
    $N,
	
	[Parameter(ParameterSetName = "compound", Mandatory = $true, Position = 0)]
	[switch]
	[Alias("")]
    $C,

    [Parameter(ParameterSetName = "post", Mandatory = $true, Position = 0)]
	[Parameter(ParameterSetName = "grains_glob", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "grains_pcre", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "pillar", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "pcre", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "list", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "ipcidr", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "nodegroup", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "compound", Mandatory = $true, Position = 1)]
	[string]
    $Target,
	
	[Parameter(ParameterSetName = "post", Mandatory = $true, Position = 1)]
	[Parameter(ParameterSetName = "grains_glob", Mandatory = $true, Position = 2)]
	[Parameter(ParameterSetName = "grains_pcre", Mandatory = $true, Position = 2)]
	[Parameter(ParameterSetName = "pillar", Mandatory = $true, Position = 2)]
	[Parameter(ParameterSetName = "pcre", Mandatory = $true, Position = 2)]
	[Parameter(ParameterSetName = "list", Mandatory = $true, Position = 2)]
	[Parameter(ParameterSetName = "ipcidr", Mandatory = $true, Position = 2)]
	[Parameter(ParameterSetName = "nodegroup", Mandatory = $true, Position = 2)]
	[Parameter(ParameterSetName = "compound", Mandatory = $true, Position = 2)]
	[string]
    $Function,
	
	[Parameter(ParameterSetName = "post", Mandatory = $false, Position = 2)]
	[Parameter(ParameterSetName = "grains_glob", Mandatory = $false, Position = 3)]
	[Parameter(ParameterSetName = "grains_pcre", Mandatory = $false, Position = 3)]
	[Parameter(ParameterSetName = "pillar", Mandatory = $false, Position = 3)]
	[Parameter(ParameterSetName = "pcre", Mandatory = $false, Position = 3)]
    [Parameter(ParameterSetName = "list", Mandatory = $false, Position = 3)]
    [Parameter(ParameterSetName = "ipcidr", Mandatory = $false, Position = 3)]
	[Parameter(ParameterSetName = "nodegroup", Mandatory = $false, Position = 3)]
	[Parameter(ParameterSetName = "compound", Mandatory = $false, Position = 3)]
	[string]
    $Arguments,
	
	[Parameter(ParameterSetName = "post", Mandatory = $false, Position = 3)]
	[Parameter(ParameterSetName = "grains_glob", Mandatory = $false, Position = 4)]
	[Parameter(ParameterSetName = "grains_pcre", Mandatory = $false, Position = 4)]
	[Parameter(ParameterSetName = "pillar", Mandatory = $false, Position = 4)]
	[Parameter(ParameterSetName = "pcre", Mandatory = $false, Position = 4)]
    [Parameter(ParameterSetName = "list", Mandatory = $false, Position = 4)]
    [Parameter(ParameterSetName = "ipcidr", Mandatory = $false, Position = 4)]
	[Parameter(ParameterSetName = "nodegroup", Mandatory = $false, Position = 4)]
	[Parameter(ParameterSetName = "compound", Mandatory = $false, Position = 4)]
	[switch]
    $Loud
  		
)


Begin {
	
	$ErrorActionPreference = "Stop"
	
	Renew-Ticket
	
	If ( $Return.Result -match $False ) { break }
	  
    Function Run-SaltState ( $Post ) {
	
		#Error handling
		trap {
	
			If ( $_.Exception.Message -match "Unauthorized" ) {

				$Return = New-Object PSObject -Property ([ordered]@{ "Error" = "Unauthorized" ; "Result" = $False })
				
				If ( $Loud ) {
					
					return $Return | ft -AutoSize
				}
				
				Else {
				
					return $Return
				}
			}
						
			continue
		}
					
		$webRequest = [System.Net.WebRequest]::Create( $url )
		$webRequest.Method = "POST"
		$webRequest.Headers.Add("X-Auth-Token", $Token_Obj.Token)
		$webRequest.Accept = "application/x-yaml"
		$webRequest.ContentType = "application/x-www-form-urlencoded"

		$bytes = [System.Text.Encoding]::ASCII.GetBytes($Post)
		$webRequest.ContentLength = $bytes.Length

		$requestStream = $webRequest.GetRequestStream()
		$requestStream.Write($bytes, 0, $bytes.Length)
		
	
		$requestStream.Close()
		
		$global:reader = New-Object System.IO.Streamreader -ArgumentList $webRequest.GetResponse().GetResponseStream()
	
		$Jobs = $reader.ReadToEnd()

  		$reader.Close()
				
		$Jobs -match "(- jid:) '(.*)'" | Out-Null

        #$Jobs 
		
		$Jid_String = $Matches[2]
		
        $Jid_Object = New-Object PSObject -Property @{ "jid" = $Jid_String }
						
		return $Jid_Object
		
	}
	
	$Expr_Form = "glob"
	
	If ( $PSBoundParameters.ContainsKey('G') ) {
		
		$Expr_Form = "grain"
	}
	
	ElseIf ( $PSBoundParameters.ContainsKey('grain_pcre') ) {
		
		$Expr_Form = "grain_pcre"
	}
	
	ElseIf ( $PSBoundParameters.ContainsKey('I') ) {
		
		$Expr_Form = "pillar"
	}

    ElseIf ( $PSBoundParameters.ContainsKey('E') ) {
		
		$Expr_Form = "pcre"
	}

    ElseIf ( $PSBoundParameters.ContainsKey('L') ) {
		
		$Expr_Form = "list"
	}

    ElseIf ( $PSBoundParameters.ContainsKey('S') ) {
		
		$Expr_Form = "ipcidr"
	}
	
	ElseIf ( $PSBoundParameters.ContainsKey('N') ) {
		
		$Expr_Form = "nodegroup"
	}
	
	ElseIf ( $PSBoundParameters.ContainsKey('C') ) {
		
		$Expr_Form = "compound"
	}
		
    If ( $Arguments ) {
	
		$SaltArguments = ""
		
		If ( $Function -notmatch "cmd.run" ) {
		
			If ( $Arguments -match "(?:.*)\S(.*)" ) {
		
				$Arg = $Arguments -replace " ", ","

    			$Arg = $Arg -split ","
		
			}
			
			Else {

    			$Arg = $Arguments -replace ", ", ","

    			$Arg = $Arg -split ","
			}
		}
		
		Else {
		
			$Arg = $Arguments -replace ", ", ","

    		$Arg = $Arg -split ","
		
		}
		
    	$Arg | % {
       
        	$SaltArguments = $SaltArguments + "&arg=$_"

    	}

    	If ( $Function -match "state.sls" ) {
			
			If ( $Environment -match "Production" ) {
			
				$SaltArguments = $SaltArguments + "&arg=env=base"
			
			}
			
			Else {
					
				$SaltArguments = $SaltArguments + "&arg=env=$Environment"
			}
    	}
		
		$Post = "client=local&tgt=$Target&fun=$Function&timeout=10" + $SaltArguments + "&expr_form=$Expr_Form"
	
	}
	
	Else {
			
		$Post = "client=local&tgt=$Target&fun=$Function&timeout=10&expr_form=$Expr_Form"
	
	}   
    
       
} #End Begin

Process {
   
   		Run-SaltState $Post	

} # End Process

End {

	$Post = $null
	$SaltArguments = $null
	$Expr_Form = $null
	$Jid_Object = $null
	$Jid_String = $null
	$Jobs = $null
	$Return = $null

}
} # End Salt

Function Salt-Run {

<#

.Synopsis

Salt-Run gets job results based on the jid number (equivalent to salt-run jobs.lookup_jid)

.Description

Salt-Run connects to Salt API and gets job results based on the jid number. It will try to get result 5 times in a row with 2 seconds delay between the tries.

Salt-Run automatically reconnects to salt master if the authorization token expired.

.Parameter Jid

Jid number of the salt job.

.Parameter Loud

Formats error output for easy reading. Use it of you are working interactively, skip if you need to capture error output in your script.

.Example

Salt-Run 20140714150702830488

Gets job result for jid 20140714150702830488. You can also use Salt-Run –jid 20140714150702830488.

.Example

Salt-Run 20140714150702830488 -Loud

Gets job result for jid 20140714150702830488 and formats results for easy reading in PowerShell window.

.Example

Salt "*" test.ping | salt-run -Loud

Executes test.ping command on all salt minions and returns formatted result.

#>

[CmdletBinding(SupportsShouldProcess = $false, DefaultParameterSetname = "result", ConfirmImpact="Medium")] 

param (

    [Parameter(ParameterSetName = "result", Mandatory = $true, ValueFromPipelineByPropertyName = $True, 
	 			ValueFromPipeline = $True, Position = 0)]
	[string]
    $Jid,
	
	[Parameter(ParameterSetName = "result", Mandatory = $false, Position = 1)]
	[switch]
    $Loud
)

Begin {

	$ErrorActionPreference = "Stop"
	
	Renew-Ticket
	
}

Process {

	#Error handling
	trap {

		If ( $_.Exception.Message ) { 
			
			cls 
			
			If ( $Loud ) {
								
				Write-Host "Getting resuls..." -ForegroundColor Green
			
			}
			
			Start-Sleep 3
			
			cls
			
			Salt-Run $Jid
		
		}
								
		continue
	}

    If ( $Jid -match $False ) { 
	
			$Return = New-Object PSObject -Property ([ordered]@{ "jid" = "No jid" ; "Result" = $False })
			
			If ( $Loud ) {
			
				return $Return | ft -Wrap -AutoSize
				
			}
			
			Else {
			
				return $Return
			
			}
	}
	
	ElseIf ( $Jid -notmatch "\A[\d.+]{20}\Z" ) { 
	
		$Return = New-Object PSObject -Property ([ordered]@{ "jid" = "Incorrect syntax or empty string" ; "Result" = $False })
		
		If ( $Loud ) {
		
			return $Return | ft -AutoSize
		}
		
		Else {
		
			return $Return
		
		}
	}
	
    Else {
       
	   	$Count = 0
		
        Function Internal {
		
			$Count ++
		
            Start-Sleep 10

	        $urlJobs = $saltMaster_Url + "/jobs/" + $Jid
		
		    $Header = @{ "X-Auth-Token" = $Token_Obj.Token }
		
		    $Results = (Invoke-WebRequest -Uri $urlJobs -Method Get -ContentType "application/x-yaml" -Headers $Header).Content

		    $ResultsJSON = $Results | ConvertFrom-Json
		
		    If ( ($ResultsJSON.return | Out-String).Length -ne 2 -and $ResultsJSON.return -notmatch "Welcome"  ) {
			
				cls
		
			    $minion = ($ResultsJSON.return | gm | ? { $_.Name -match ".com" } | Select Name).Name
											
	    	    If ( $minion.Count -eq 1 ) {
			
				    $minion -match "(.*)`.<you domain here>" | Out-Null

				    $minion = $Matches[1]
				
				    $ResultsFinal = $ResultsJSON.return | Select -ExpandProperty *
								    				
				    If ( $Loud ) {
					
						If ( ($ResultsFinal | gm -MemberType NoteProperty).Count -eq 0 ) {  
						
							$ResultsFinal_Obj = New-Object PSObject -Property ( [ordered]@{ "Minion" = $minion ; "Result" = $ResultsFinal } )
							
							return $ResultsFinal_Obj | ft -AutoSize -Wrap
						}
						
						Else {
																				
							$ResultsFinal_Obj = New-Object PSObject -Property ( [ordered]@{ "Minion" = $minion ; "Result" = $ResultsFinal } )
							
							$ResultsFinal_Obj | ConvertTo-Json
																			
						}
					}
					
					Else {
					
						$ResultsFinal_Obj = New-Object PSObject -Property ( [ordered]@{ "Minion" = $minion ; "Result" = $ResultsFinal } )
						
						return $ResultsFinal_Obj
					
					}
			    }
			
			    Else {
			
				    $ResultsFinal = $ResultsJSON.return
				
				    If ( $Loud ) {

						$ResultsFinal | ConvertTo-Json
					}
					
					Else {
					
						return $ResultsFinal
					
					}
			    }
		
		    }
			
		    Else {
				
				#Trying to get result 5 times. Return jid after that (for manual verification - salt-run $jid).
				If ( $Count -le 5 ) {
					
					If ( $Loud ) { 
					
						Write-Host "$Count attempt to get results (max 5)..." -ForegroundColor Yellow 

                        Start-Sleep 2
						
						Internal
					}
					
					Else {

                        
                        Start-Sleep 2
					
						Internal
					}
				}

	            Else { 
				
					$Return = New-Object PSObject -Property ([ordered]@{ "jid" = $Jid ; "Error" = "No results received" ; "Result" = $False })
					
					If ( $Loud ) {
					
						return $Return | ft -AutoSize
						
					}
					
					Else {
					
						return $Return
					}
				}
		    }
			
		} #End Internal
		
	Internal
    
	}
}

End { 
    
    $ResultsJSON = $null
    $ResultsFinal = $null    
	$ResultsFinal_Obj = $null
	$Results = $null
	$Return = $null
	$Count = $null
	$Array = $null
}

}

Function Renew-Ticket {

	$ErrorActionPreference = "Stop"

	#Error handling
	trap {
	
		If ( $_.Exception.Message -match "Cannot index into a null array" ) {
			
			$Return = New-Object PSObject -Property ([ordered]@{ "Error" = "Not Connected to Salt Master" ; "Result" = $False })

			return $Return
			
		}
	
		continue
	}

	$CurrentTime = Get-Date

	If ( $CurrentTime -le $Token_Obj.Experation ) {

		# Token did not expire. Nothing to do.

	}

	Else {

		# Renew token
		
		$RegEx = "http://(.*):8000"

		$saltMaster_Url -match $RegEx | Out-Null

		$saltMaster = $Matches[1]

		Salt-Connect $saltMaster
	}
}

Export-ModuleMember Salt-Connect, Salt, Salt-Run
