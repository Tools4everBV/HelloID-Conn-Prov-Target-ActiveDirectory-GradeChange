#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json;

$success = $False
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Support Functions
function New-RandomPassword($PasswordLength) {
    if($PasswordLength -lt 8) { $PasswordLength = 8}
        
    # Used to store an array of characters that can be used for the password
    $CharPool = New-Object System.Collections.ArrayList

    # Add characters a-z to the arraylist
    for ($index = 97; $index -le 122; $index++) { [Void]$CharPool.Add([char]$index) }

    # Add characters A-Z to the arraylist
    for ($index = 65; $index -le 90; $index++) { [Void]$CharPool.Add([Char]$index) }

    # Add digits 0-9 to the arraylist
    $CharPool.AddRange(@("0","1","2","3","4","5","6","7","8","9"))
        
    # Add a range of special characters to the arraylist
    $CharPool.AddRange(@("!","""","#","$","%","&","'","(",")","*","+","-",".","/",":",";","<","=",">","?","@","[","\","]","^","_","{","|","}","~","!"))
        
    $password=""
    $rand=New-Object System.Random
        
    # Generate password by appending a random value from the array list until desired length of password is reached
    1..$PasswordLength | foreach { $password = $password + $CharPool[$rand.Next(0,$CharPool.Count)] }  
        
    $password
}
#endregion Support Functions

#region Change mapping here
    #region Grade Changes
    $enableGradeChange = $false;

    $gradeChangeConfig = @{
        PasswordGroup = "PwdPolicyGroupName";
        Password = New-RandomPassword(8);
        OldGrade = '3'
        NewGrade = '4'
    }
    #endregion Grade Changes

  
#endregion Change mapping here

#region Execute
    #Get Current Account
    $previousAccount = Get-ADUser -Identity $aRef -Server $pdc

    #region Grade Change
    if($enableGradeChange)
    {
        # Evaluate Grade Levels
        if(-Not [string]::IsNullOrWhiteSpace($p.Custom.Grade) -AND -Not [string]::IsNullOrWhiteSpace($pp.Custom.Grade))
        {
            # Confirm Grade Level within Scope
            if($pp.Custom.Grade -eq $gradeChangeConfig.OldGrade -and $p.Custom.Grade -eq $gradeChangeConfig.NewGrade)
            {
                Write-Information "Processing Grade Change";
                try{
                        #region Grade Change
                        if(-Not($dryRun -eq $True)) {
                            
                            Set-ADAccountPassword -Identity $aRef -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $defaultPassword -Force) -Server $pdc
                                $auditLogs.Add([PSCustomObject]@{
                                    Action = "UpdateAccount"
                                    Message = "Grade Change [$($pp.Custom.Grade)] to [$($p.Custom.Grade)] - Account password updated for $($previousAccount.userName)"
                                    IsError = $False
                                })
                        }
                        $success = $true
                }catch{
                    $success = $false
                    $auditLogs.Add([PSCustomObject]@{
                        Action = "UpdateAccount"
                        Message = "Error: Grade Change [$($pp.Custom.Grade)] to [$($p.Custom.Grade)] - Account password failed to update for $($previousAccount.userName)"
                        IsError = $true;
                    });
                    Write-Error $_
                }
            }
        }
    }
    #endregion Grade Change

    #Get Updated Account
    $updatedAccount = Get-ADUser -Identity $aRef -Server $pdc
    
#endregion Execute

#region Build up result
$result = [PSCustomObject]@{
    Success = $success
    AccountReference = $aRef
    AuditLogs = $auditLogs;
    Account = $updatedAccount
    PreviousAccount = $previousAccount
    
    #ExportData = [PSCustomObject]@{
    #    
    #}
};
  
Write-Output ($result | ConvertTo-Json -Depth 10)
#endregion Build up result