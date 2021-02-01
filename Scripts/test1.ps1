# Author: Shawn Keene, adapted from Rhys Campbell http://www.youdidwhatwithtsql.com/automating-internet-explorer-with-powershell/467/
# Date: 8/26/2015
# Powershell script to automate Internet Explorer

cls
$username = "sarah";
$password = "monkey";
$loginUrl = "http://example.com";
$shopID = "A1C";
$AddProdURL = "https://example.com/global/ProductAdd";
$iterator = 1;

#initialize browser
$ie = New-Object -com internetexplorer.application;
$ie.visible = $true;
$ie.navigate($loginUrl);
while ($ie.Busy -eq $true) { Start-Sleep -Seconds 1; }    #wait for browser idle

#login
($ie.document.getElementsByName("username") |select -first 1).value = $username;
($ie.document.getElementsByName("password") |select -first 1).value = $password;
($ie.document.getElementsByName("login") |select -first 1).click();
while ($ie.Busy -eq $true) { Start-Sleep -Seconds 1; }    #wait for browser idle

#choose shop
($ie.document.getElementsByName("shop") |select -first 1).value = $shopID;
($ie.document.getElementsByName("submit") |select -first 1).click();
while ($ie.Busy -eq $true) { Start-Sleep -Seconds 1; }    #wait for browser idle

start-sleep -seconds 2

$products = import-csv products.csv | foreach {
    write-host Product $iterator -  $_.ITEM_NUMBER

    #go to product addition form
    $ie.navigate($AddProdURL);
    while ($ie.Busy -eq $true) { Start-Sleep -Seconds 1; }    #wait for browser idle

    #fill out form fields
    ($ie.document.getElementsByName("item_number") |select -first 1).value = $_.ITEM_NUMBER;
    ($ie.document.getElementsByName("item_name") |select -first 1).value = $_.ITEM_NAME;
    ($ie.document.getElementsByName("item_type") |select -first 1).value = "C";
    ($ie.document.getElementsByName("short_description") |select -first 1).value = $_.ShortProductDescription;
    ($ie.document.getElementsByName("long_description") |select -first 1).value = $_.LongDescription;
    ($ie.document.getElementsByName("legal") |select -first 1).click();
    ($ie.document.getElementsByName("legal_text") |select -first 1).value = $_.LegalText;
    ($ie.document.getElementsByName("submit") |select -first 1).click();

    $iterator = $iterator+1;
}

Write-Host -ForegroundColor Green "All Done!";