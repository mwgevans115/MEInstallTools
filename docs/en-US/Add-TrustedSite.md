---
external help file: MEInstallTools-help.xml
Module Name: MEInstallTools
online version:
schema: 2.0.0
---

# Add-TrustedSite

## SYNOPSIS
The PowerShell script which can be used to add trusted sites in Internet Explorer.

## SYNTAX

### SingleDomain
```
Add-TrustedSite -TrustedSites <String[]> [-HTTP] [<CommonParameters>]
```

### CombineDomain
```
Add-TrustedSite [-HTTP] -PrimaryDomain <String> -SubDomain <String> [<CommonParameters>]
```

## DESCRIPTION
The PowerShell script which can be used to add trusted sites in Internet Explorer.

## EXAMPLES

### EXAMPLE 1
```
C:\AddingTrustedSites.ps1 -TrustedSites "contoso1.com","contoso2.com" -HTTP
```

Successfully added 'contoso1.com' and 'contoso2.com' domain to trusted sites in Internet Explorer.

This command will add 'contoso1.com' and 'contoso2.com' domain to trusted sites in Internet Explorer respectively.

### EXAMPLE 2
```
C:\AddingTrustedSites.ps1  -PrimaryDomain "contoso.com" -SubDomain "test.domain"
```

Successfully added 'test.domain.contoso.com' domain to trusted sites in Internet Explorer.

This command will add 'test.domain.contoso.com' domain to trusted sites in Internet Explorer.

## PARAMETERS

### -TrustedSites
Spcifies the trusted site in Internet Explorer.

```yaml
Type: String[]
Parameter Sets: SingleDomain
Aliases: Sites

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -HTTP
Once you use the HTTP switch parameter, the domain will be use the http:// prefix.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -PrimaryDomain
Spcifies the primary domain in Internet Explorer.

```yaml
Type: String
Parameter Sets: CombineDomain
Aliases: pdomain

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SubDomain
Spcifies the sub domain in Internet Explorer.

```yaml
Type: String
Parameter Sets: CombineDomain
Aliases: sdomain

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
