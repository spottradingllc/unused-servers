Function List-ZooExceptions {

	Param (

		[string]
		[Parameter( Mandatory = $true )]
		$ZooNode,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Auth
	)
	
	$originalColor = $Host.UI.RawUI.ForegroundColor
	$originalBackColor = $Host.UI.RawUI.BackgroundColor

	$ZookeeperResult = @()
	
	$ExhibitorAuth = @{ "Authorization" = $Auth }
				
	$Uri = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/node?key=/UnusedServersException"

	Try {
	
		$Exceptions = Invoke-RestMethod -Uri $Uri -Method Get -Header $ExhibitorAuth -TimeoutSec 20
			
		$Exceptions | % {

			$ZooTemp = @{}

			$Uri2 = "http://" + $ZooNode + ":8080/exhibitor/v1/explorer/node-data?key=" + $_.key
		
			$ZooTemp.Description = ( Invoke-RestMethod -Uri $Uri2 -Method Get -Header $ExhibitorAuth -TimeoutSec 20 ).str
		
			$ZooTemp.Name = $_.title
		
			$ZookeeperResult += New-Object PSObject -Property $ZooTemp
				
		}
			
		$ZookeeperResult = $ZookeeperResult | ft -AutoSize 
					
		$ZookeeperResult | % { $Host.UI.RawUI.ForegroundColor = "Green";  $Host.UI.RawUI.BackgroundColor = "Black"; $_ }
		""
			
		$ZookeeperResult = $null
			
		$Host.UI.RawUI.ForegroundColor = $originalColor
		$Host.UI.RawUI.BackgroundColor = $originalBackColor
	
	}
	
	Catch { $_ ; break }
		
}