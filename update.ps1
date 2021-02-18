#Initialize default properties
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json;
$pp = $previousPerson | ConvertFrom-Json;
$pd = $personDifferences | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json;

$success = $False;
$auditMessage = "for person " + $p.DisplayName;

# Log Grade Level old and new
Write-Verbose -Verbose "Previous Grade: $($pp.Custom.Grade)"
Write-Verbose -Verbose "Current Grade: $($p.Custom.Grade)"

# Generate password based on grade level
$lowerGrades = @("-2","-1","0","1","2","3");
if($lowerGrades -contains ($p.Custom.Grade))
{
    $defaultPassword = "hello" + $p.Name.GivenName.ToLower();
}
else
{
    $formattedDate = (Get-Date -Date $p.details.birthdate).ToUniversalTime().toString("MMddyyyy")
    $defaultPassword = "$($p.Name.GivenName.substring(0,1).ToUpper())$($p.Name.FamilyName.substring(0,1).ToUpper())#$($formattedDate)";
}
$account = @{ password = $defaultPassword };


# Evaluate Grade Levels
if($p.Custom.Grade -ne $null -and $pp.Custom.Grade -ne $null)
{
    # Confirm Grade Level within Scope
	if($p.Custom.Grade -eq '4' -and $pp.Custom.Grade -eq '3')
    {
        # Execute Password Change
		Write-Verbose -Verbose "Update Password";
        try
        {
            $account = Get-ADUser -Identity $aRef;
            
            if(-Not($dryRun -eq $True)) {
                Set-ADAccountPassword -Identity $aRef -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $account.password -Force)
            }
            Write-Verbose -Verbose "password updated";
            $auditMessage = "password updated";
            $success = $true;
        }
        catch
        {
            $auditMessage = "$($_)";
        }
    }
    else
    {
        Write-Verbose -Verbose "Skip Password Update (Grade)";
        $auditMessage = "skipped for person (Grade)";
        $success = $true;
    }
}
else
{
    Write-Verbose -Verbose "Skip Password Update (null values)";
    $auditMessage = "skipped for person (null values)";
    $success = $true;
}

#build up result
$result = [PSCustomObject]@{
	Success= $success;
	AccountReference= $aRef;
	AuditDetails=$auditMessage;
    Account = $account;
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 10