Function Get-ZookeeperNode {

	Param (
		[string]
		[Parameter( Mandatory = $true )]
		$ZooNodes
	)
	
	$Zoo = @( ($ZooNodes -replace " ", "") -split ",")
		
	Try {
		Do {
		
			$ZooNodeTry = $Zoo | Get-Random
			
			$Connection = Test-Connection $ZooNodeTry -Quiet -Count 1
			
			If ( $Connection ) { $global:ZooNode = $ZooNodeTry }
			Else { Write-Host $ZooNodeTry "is down! Searching for another one." }
		}
		
		Until ( $ZooNode )
		
		Return $ZooNode
	}
	
	Catch { $_ ; break }
			
}