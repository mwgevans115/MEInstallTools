---
external help file: MEInstallTools-help.xml
Module Name: MEInstallTools
online version:
schema: 2.0.0
---

# Write-LogScriptParameter

## SYNOPSIS
Returns the parameters defined for a calling script

## SYNTAX

```
Write-LogScriptParameter [[-ParameterName] <String[]>] [-LogFormatLength <Int32>] [-LogLineLength <Int32>]
 [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### EXAMPLE 1
```
Write-LogScriptParameter
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

### -LogFormatLength
{{ Fill LogFormatLength Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 19
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogLineLength
{{ Fill LogLineLength Description }}

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: $Host.UI.RawUI.BufferSize.Width - $LogFormatLength
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Name: Write-LogScriptParameter
Author: Mark Evans \<mark@madspaniels.co.uk\>
Version: 1.0
DateCreated: 2020-Dec-10

## RELATED LINKS
