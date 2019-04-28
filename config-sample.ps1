$SophosSettings = @{
    "user" = "token";
    "password" ="yoursophostoken";
    "adminURL" = "https://fw.domain.local:4444"
}

$FortigateSettings = @{
    "user" = "admin";
    "password" = "youradminpassword";
    "adminURL" = "https://fortigate.domain.local";
}

# Create DNS records in the Fortigate based on the hostnames in the Sophos network objects
$TransferDNSRecords = $true

# Create Address objects it the Fortigate based on the address of the Sophos network objects
$TransferAddresses = $true

# Create DHCP reservations based on the DHCP reservations in the Sophos network objects
$TransferDHCPReservations = $true