##############################################################################################################################
#
#    Pre-req:
#    * Rename the config-sample.ps1 to config.ps1 and populate it with your own details
#    * Create a DNS database
#    * Setup a DHCP server 
#
#    Notes:
#    * Only one DNS database supported
#    * No network host object will be transferred
#    * Only one MAC address reservation per host will be transferred
#    * Requires a trusted management certificate on both machines
#      - Or that you modify the script to allow untrusted certificates:
#        https://stackoverflow.com/questions/34331206/ignore-ssl-warning-with-powershell-downloadstring
#
##############################################################################################################################

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Get the credentials
. .\config.ps1

#######################################################################################################################
#
#   Sophos section
#
#######################################################################################################################

$Pair = "$($SophosSettings.user):$($SophosSettings.password)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Pair))
$basicAuthValue = "Basic $encodedCreds"

$Headers = @{
    Authorization = $basicAuthValue
}

# Get the IP based hosts
$Result = Invoke-WebRequest "$($SophosSettings.adminURL)/api/objects/network/host/" -Headers $Headers
$SophosNetworkHosts = $Result.content | ConvertFrom-Json

#######################################################################################################################
#
#   Fortigate section
#
#######################################################################################################################

# Authentication against the box
$PostParameters = @{
    "username" = $FortigateSettings.user;
    "secretkey" = $FortigateSettings.password;
}

$Result = Invoke-WebRequest -Method POST "$($FortigateSettings.adminURL)/logincheck" -Body $PostParameters -SessionVariable FortigateSession
$CSRFTOKEN = ($FortigateSession.Cookies.GetCookies($FortigateSettings.adminURL) | Where-Object { $_.name -eq "ccsrftoken" }).value.replace("`"", "")

if($TransferDHCPReservations){
    
    #Get the DHCP server
    $Result = Invoke-WebRequest "$($FortigateSettings.adminURL)/api/v2/cmdb/system.dhcp/server/1" -WebSession $FortigateSession
    $JSONData = $Result | ConvertFrom-Json

    #Extract the actual DHCP server information
    $DHCPServer = $JSONData.results[0]
    $Id = $DHCPServer.'reserved-address'.Count

    # Store the reserved addresses in an array
    $ReservedAddresses = @();

    $SophosNetworkHosts | Where-Object { $_.macs } | ForEach-Object {

        $SophosHost = $_

        #Create it every run to make sure that we don't pass any data between the loop iterations
        $DHCPReservedTemplate = New-Object -TypeName PSObject -Property @{
            "id" = 0;
            "type" = "mac";
            "ip" = "";
            "mac" = "";
            "action" = "reserved";
            "circuit-id-type" = "string";
            "circuit-id" = "";
            "remote-id-type" = "string";
            "remote-id" = "";
            "description" = "";
        }

        # The script only supports one mac address. Not sure why we'd have more than one but I don't so I won't invest time doing it.
        
        $Id++
        $DHCPReservedTemplate.id = $Id
        $DHCPReservedTemplate.ip = $SophosHost.address
        $DHCPReservedTemplate.description = $SophosHost.name
        $DHCPReservedTemplate.mac = $SophosHost.macs[0]

        $ReservedAddresses += $DHCPReservedTemplate
        
        Write-Host "Adding $($SophosHost.name) with ip $($SophosHost.address) and mac $($SophosHost.macs): " -NoNewline
        $Body = @{ "id" = 1; "method" = "add"; "reserved-address" = @($ReservedAddresses) }
        $Body = $Body | ConvertTo-Json -Compress

        $Result = Invoke-WebRequest "$($FortigateSettings.adminURL)/api/v2/cmdb/system.dhcp/server/1" -Headers @{"Content-Type" = "application/x-www-form-urlencoded"; "X-CSRFTOKEN" = $CSRFTOKEN} -WebSession $FortigateSession -Method "PUT" -Body $Body -ErrorAction SilentlyContinue

        if($?){
            Write-Host -ForegroundColor "Green" "Success"
        } Else {
            Write-Host -ForegroundColor "Green" "Failed"
        }
    }
}

if($TransferDNSRecords){

    # Only one DNS Database is supported
    $Result = Invoke-WebRequest "$($FortigateSettings.adminURL)/api/v2/cmdb/system/dns-database/" -WebSession $FortigateSession -Method "GET"
    $JsonData = $Result.Content | ConvertFrom-Json
    $DNSDatabaseName = $JSONData.results[0].name

    $Result = Invoke-WebRequest "$($FortigateSettings.adminURL)/api/v2/cmdb/system/dns-database/$DNSDatabaseName" -WebSession $FortigateSession
    $JSONData = $Result.Content | ConvertFrom-Json
    $DNSDatabase = $JSONData.results[0]


    $id = 0
    $Records = @()

    Write-Host "Adding $($DNSDatabase.'dns-entry'.count) records from the Fortigate DNS database to the dataset"
    Foreach($Entry in $DNSDatabase.'dns-entry'){
        $Entry.id = ++$i
        $Records += $Entry
    }

    # Cache the existing host names for faster execution 
    $ExistingRecordHostNames = $Records.hostname

    $SophosNetworkHosts | Where-Object { $_.hostnames } | ForEach-Object {

        $SophosHost = $_

        Foreach($Record in $SophosHost.hostnames){
            
            #Remove everything from the first .
            $Record = $Record -Replace "\..+$", ""
            
            Write-Host -NoNewline "DNS $($Record): "

            #Check if the hostname exists
            if($ExistingRecordHostNames -contains $Record){
                Write-Host -ForegroundColor "Gray" "Skipping"
            } Else {
                Write-Host -ForegroundColor "Green" "Adding"
                $Records += New-Object -TypeName PSObject -Property @{
                    "id" = ++$id;
                    "status" = "enable"
                    "type" = "A"
                    "ttl" = 0
                    "preference" = 10
                    "ip" = $SophosHost.address
                    "ipv6" = "::"
                    "hostname" = $Record
                    "canonical-name" = ""
                }
            }
            
        }
    }

    Write-Host -NoNewline "Creating DNS database: "
    $DNSDatabase.'dns-entry' = $Records
    $Body = $DNSDatabase | ConvertTo-Json -Compress

    $Result = Invoke-WebRequest "$($FortigateSettings.adminURL)/api/v2/cmdb/system/dns-database/$DNSDatabaseName" -Headers @{"Content-Type" = "application/x-www-form-urlencoded"; "X-CSRFTOKEN" = $CSRFTOKEN} -WebSession $FortigateSession -Method "PUT" -Body $Body -ErrorAction SilentlyContinue

    if($?){
        Write-Host -ForegroundColor "Green" "Success"
    } Else {
        Write-Host -ForegroundColor "Green" "Failed"
    }

}


if($TransferAddresses){
    
    $Result = Invoke-WebRequest "$($FortigateSettings.adminURL)/api/v2/cmdb/firewall/address" -WebSession $FortigateSession
    $JSONData = $Result.Content | ConvertFrom-Json
    $FortigateAddressNames = $JSONData.results.name

    ForEach($H in $SophosNetworkHosts){
        
        Write-Host "Name: $($H.name), IP: $($H.address)/32: " -NoNewline
        if($FortigateAddressNames -Contains $H.name){
            Write-Host -ForegroundColor "Gray" "Skipping"
        } Else {
            
            $SHost = @{
                "name" = $H.name;
                "subnet" = $H.address + "/32";
            } | ConvertTo-Json -Compress

            $Result = Invoke-WebRequest "$($FortigateSettings.adminURL)/api/v2/cmdb/firewall/address" -Headers @{"Content-Type" = "application/json"; "X-CSRFTOKEN" = $CSRFTOKEN} -WebSession $FortigateSession -Method "POST" -Body $SHost -ErrorAction SilentlyContinue

            if($?){
                Write-Host -ForegroundColor "Green" "Success"
            } Else {
                Write-Host -ForegroundColor "Green" "Failed"
            }
        }
    }

}
