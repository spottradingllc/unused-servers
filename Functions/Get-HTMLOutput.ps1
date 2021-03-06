Function Get-HTMLOutput {

	Param (
	
		[array]
		[Parameter( Mandatory = $true )]
		$Data,
		
		[string]
		[Parameter( Mandatory = $true )]
		$ReportHeader,
		
		[string]
		[Parameter( Mandatory = $true )]
		$ReportDescription,
		
		[string]
		[Parameter( Mandatory = $true )]
		$FieldsToUse,
		
		[string]
		[Parameter( Mandatory = $true )]
		$Color,
		
		[string]
		[Parameter( Mandatory = $true )]
		$TableID,
		
		[string]
		[Parameter( Mandatory = $false )]
		$Font = "Kalinga"
	)

	$TableID = "t0" + $TableID

$t = @"
<meta charset="UTF-8">
<style>
table#$TableID, th, td {	
	border-width:1px;
	border-style:solid;
	border-color:black;
	border-collapse:collapse; 
}
table#$TableID th {
	background-color:$Color;
	text-align:left;
	padding:7px;
}
table#$TableID td {
	padding:7px; 
}
table#$TableID tr:nth-child(even) { background-Color:#909090; }
table#$TableID tr:nth-child(odd) { background-color:#fff; }
</style>
"@

$Pre = @"
<p style="font-family:$Font; font-size:90%" >
	<b> 
		$ReportHeader
	</b>
</p>
<p style="font-family:$Font; font-size:90%">
	<i>
		$ReportDescription
	</i>
</p>
"@

	$Post = "<br><hr>"
	
	$TableHeaders = ( $FieldsToUse -replace " ", "" ) -split ","
	
	$r = $Data | ConvertTo-Html -Head $t -PreContent $Pre -PostContent $Post -Property $TableHeaders

	$r = $r -replace "<table>", "<table id=`"$TableID`" style=`"font-family:$Font; font-size:80%`">"

	$r = $r | Out-String 

	return $r

}