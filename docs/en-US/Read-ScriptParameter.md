---
external help file: MEInstallTools-help.xml
Module Name: MEInstallTools
online version:
schema: 2.0.0
---

# Read-ScriptParameter

## SYNOPSIS
Returns the parameters defined for a calling script

## SYNTAX

```
Read-ScriptParameter [[-ParameterName] <String[]>] [-IncludeBoundParameters] [-ApplicationData <String>]
 [-UseStored] [-Store] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### EXAMPLE 1
```
Read-ScriptParameter
```

## PARAMETERS

### -ParameterName
Parameter Name - leave blank for all

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -IncludeBoundParameters
Switch to include bound parameters

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

### -ApplicationData
Application datapath to store defaults

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: (Join-Path $env:APPDATA '\Microsoft\Windows\Powershell\ParameterData')
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseStored
Switch to use stored defaults

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

### -Store
Switch to save defaults

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

## OUTPUTS

## NOTES
Name: Read-ScriptParameter
Author: Mark Evans \<mark@madspaniels.co.uk\>
Version: 1.0
DateCreated: 2020-Dec-10

## RELATED LINKS
