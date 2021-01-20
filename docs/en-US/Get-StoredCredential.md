---
external help file: CredentialManager.dll-Help.xml
Module Name: CredentialManager
online version:
schema: 2.0.0
---

# Get-StoredCredential

## SYNOPSIS
{{ Fill in the Synopsis }}

## SYNTAX

```
Get-StoredCredential [-Target <String>] [-Type <CredType>] [-AsCredentialObject] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Target
{{ Fill Target Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Type
Specifies the type of credential to return, possible values are [GENERIC, DOMAIN_PASSWORD, DOMAIN_CERTIFICATE, DOMAIN_VISIBLE_PASSWORD, GENERIC_CERTIFICATE, DOMAIN_EXTENDED, MAXIMUM, MAXIMUM_EX]

```yaml
Type: CredType
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Generic
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsCredentialObject
Switch to return the credentials as Credential objects instead of the default PSObject

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
