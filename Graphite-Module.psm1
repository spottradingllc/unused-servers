Function Connect-ToGraphite {
	
	param (
	
		[Parameter( Mandatory = $true )]
        [string]
        [ValidatePattern("<Graphite server 01|Graphite Server 02>")]
        $GraphiteServer
	
	)
	
	$ErrorActionPreference = "Stop"

	#Error handling
	trap {
		
		If ($_.Exception.Message -match "target machine actively refused") {
		
			Write-Host "Reconnecting to $Graphite ..."
			
			Start-Sleep 10
			
			Connect-ToGraphite
			
		}
		
		Else { $_.Exception.Message }
			
		continue		
	}

	#Socket to send results to Graphite server
	$global:socket = new-object System.Net.Sockets.TcpClient($GraphiteServer, 2103)
	$global:stream = $socket.GetStream()
	$global:writer = new-object System.IO.StreamWriter $stream

	""
	Write-Host "Connected to $GraphiteServer"
	
}
	
Function Send-ToGraphite {

    param (

        [Parameter( Mandatory = $true )]
        [datetime]
        $Time,

        [Parameter( Mandatory = $true )]
        [string]
        $CustomPath,

        [Parameter( Mandatory = $true )]
        [int]
        $Value,

        [Parameter( Mandatory = $true )]
        [string]
        [ValidatePattern("<Graphite server 01|Graphite Server 02>")]
        $GraphiteServer

    )

    Connect-ToGraphite $GraphiteServer
	
	#Sending snapshot start time to Graphite
	$TimeUTC = (Get-Date $Time).ToUniversalTime()
			
	#Get Timestamp of stats and convert to UNIX timestamp
	$DateEpoch = [int][double]::Parse((Get-Date -Date $TimeUTC -UFormat %s))
			
	$GraphiteData = "$CustomPath $Value $DateEpoch"

 	Write-Host "Sending $GraphiteData to $GraphiteServer"
	""
	
	$writer.WriteLine( $GraphiteData )
	$writer.Flush()
	
	$writer.Close()
	$stream.Close()
	$socket.Close()

 }
 
 Export-ModuleMember Send-ToGraphite