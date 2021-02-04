---
external help file: MEInstallTools-help.xml
Module Name: MEInstallTools
online version:
schema: 2.0.0
---

# Set-InitialLogging

## SYNOPSIS
Function to Initialise Logging

## SYNTAX

```
Set-InitialLogging [[-LiteralPath] <String>] [[-logging_defaultlevel] <Object>] [[-DefaultFormat] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### EXAMPLE 1
```
Set-InitialLogging -LiteralPath 'C:\fred.log'
```

## PARAMETERS

### -LiteralPath
{{ Fill LiteralPath Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -logging_defaultlevel
{{ Fill logging_defaultlevel Description }}

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DefaultFormat
{{ Fill DefaultFormat Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: [%{timestamp:+%T}] [%{level:-7}] %{message}
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.IO.FileInfo
## NOTES
Name: Set-InitialLogging
Author: Mark Evans
Version: 1.0
DateCreated: 02/02/2021

## RELATED LINKS
