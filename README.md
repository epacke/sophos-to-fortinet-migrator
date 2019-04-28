# Sophos to Fortigate migrating script

## Background
I have had my Sophos UTM VM for almost 3 years and really love the product. It's super easy to manage and has great functionality. However, it was time to learn something new and given the rise of Fortinet during the last few years I decided to purchase a Fortigate.
Since I had quite a number of objects, DNS and DHCP reservations I decided to automate that process. Rules were quite few so I made that part manually.

## What it does
 - Creates Fortigate Address objects based on the Sophos host objects
 - Creates Fortigate DNS records in the local DNS database based ont he Sophos host objects
 - Creates MAC address reservations in the DHCP server based on the Sophos host objects

## What it does not
- Does not migrate network objects, only /32
- Does not support more than one mac reservation per host (not even sure why Sophos supports it)
- Does not support more than one DNS database.
- Does not do anything else than what is stated above.

## How to use

 1. Rename the `config-sample.ps1` to `config.ps1`
 2. Edit `config.ps1` and add your credentials and management addresses
 3. Create a local DNS database on your Fortigate
 4. Create a DHCP server on one of your internal interfaces on your Fortigate
