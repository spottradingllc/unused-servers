Function SendEmail {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$EmailBody,
		
		[string]
		[Parameter( Mandatory = $true )]
		$emailSubject,
		
		[string]
		[Parameter( Mandatory = $true )]
		$From,
		
		[string]
		[Parameter( Mandatory = $true )]
		$To,
		
		[string]
		[Parameter( Mandatory = $false )]
		$CC,

		[string]
		[Parameter( Mandatory = $true )]
		$SMTP
	
	)

	$Body = $EmailBody | Out-String
	
	$Email_Params = @{
	
		"From" = $From ;
		"To" = $To ;
		"Priority" = "High" ;
		"Subject" = $emailSubject ;
		"Body" = $EmailBody ;
		"SMTP" = $SMTP ;
		"BodyAsHTML" = $true
	}
	
	If ( $CC ) { $Email_Params.Add( "CC", $CC ) }
	
	Send-MailMessage @Email_Params
}