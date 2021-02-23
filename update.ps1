#Initialize default properties
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json

$success = $False
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

# Get Primary Domain Controller
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator

# Log Grade Level old and new
Write-Information "Previous Grade: $($pp.Custom.Grade)"
Write-Information "Current Grade: $($p.Custom.Grade)"

# Generate password based on grade level
$lowerGrades = @("-2","-1","0","1","2","3")
if($lowerGrades -contains ($p.Custom.Grade))
{
    $defaultPassword = "hello" + $p.Name.GivenName.ToLower()
}
else
{
    $formattedDate = (Get-Date -Date $p.details.birthdate).ToUniversalTime().toString("MMddyyyy")
    $defaultPassword = "$($p.Name.GivenName.substring(0,1).ToUpper())$($p.Name.FamilyName.substring(0,1).ToUpper())#$($formattedDate)"
}

# Evaluate Grade Levels
if(-Not [string]::IsNullOrWhiteSpace($p.Custom.Grade) -AND -Not [string]::IsNullOrWhiteSpace($pp.Custom.Grade))
{
    # Confirm Grade Level within Scope
    if($p.Custom.Grade -eq '4' -and $pp.Custom.Grade -eq '3')
    {
        # Execute Password Change
        Write-Information "Update Password"
        try
        {
            $previousAccount = Get-ADUser -Identity $aRef
            
            if(-Not($dryRun -eq $True)) {
                Set-ADAccountPassword -Identity $aRef -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $defaultPassword -Force) -Server $pdc
                $auditLogs.Add([PSCustomObject]@{
                    # Action = "UpdateAccount" Optionally specify a different action for this audit log
                    Message = "Account password updated for $($account.userName)"
                    IsError = $False
                })
            }
            $account = Get-ADUser -Identity $aRef
            Write-Information "Password updated"
            $success = $True
        }
        catch
        {
            $auditLogs.Add([PSCustomObject]@{
                # Action = "UpdateAccount" Optionally specify a different action for this audit log
                Message = "Account password failed to update for $($account.userName):  $_"
                IsError = $True
            })
        }
    }
    else
    {
        Write-Information "Skip Password Update (Grade)"
        # No audit entry as nothing changed.
        $success = $True
    }
}
else
{
    Write-Information "Skip Password Update (null values)"
    # No audit entry as nothing changed.
    $success = $True
}

#build up result
$result = [PSCustomObject]@{
    Success = $success
    AccountReference = $aRef
    AuditLogs = $auditLogs
    Account = $account
    PreviousAccount = $previousAccount
        
    # Optionally update the data for use in other systems
    <#
    ExportData = [PSCustomObject]@{
        displayName = $account.DisplayName
        userName = $account.UserName
    }
    #>
}

#send result back
Write-Output ($result | ConvertTo-Json -Depth 10)
