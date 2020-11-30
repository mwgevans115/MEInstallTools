---
external help file: MEInstallTools-help.xml
Module Name: MEInstallTools
online version:
schema: 2.0.0
---

# New-File

## SYNOPSIS
Demonstrates how to write a command that works with paths that do
not allow wildards and do not have to exist.

## SYNTAX

```
New-File [-Path] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This command does not require a LiteralPath parameter because the
Path parameter can handle paths that use wildcard characters. 
That's
because this command does not "resolve" the supplied path.
This command
also does not verify the path exists because the point of the command is
to create a new file at the specified path.

## EXAMPLES

### EXAMPLE 1
```
New-File -Path xyzzy[1].txt -WhatIf
```

This example shows how the Path parameter can handle a path that happens
to use the wildcard chars "\[" and "\]" and does not exist to start with.

## PARAMETERS

### -Path
Specifies a path to one or more locations.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: PSPath

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
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
Author: Mark Evans

## RELATED LINKS
