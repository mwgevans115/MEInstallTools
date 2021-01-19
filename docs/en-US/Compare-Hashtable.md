---
external help file: MEInstallTools-help.xml
Module Name: MEInstallTools
online version:
schema: 2.0.0
---

# Compare-Hashtable

## SYNOPSIS
Compare two Hashtable and returns an array of differences.

## SYNTAX

```
Compare-Hashtable [-Left] <Hashtable> [-Right] <Hashtable> [<CommonParameters>]
```

## DESCRIPTION
The Compare-Hashtable function computes differences between two Hashtables.
Results are returned as
an array of objects with the properties: "key" (the name of the key that caused a difference),
"side" (one of "\<=", "!=" or "=\>"), "lvalue" an "rvalue" (resp.
the left and right value
associated with the key).

## EXAMPLES

### EXAMPLE 1
```
" 5).
```

Compare-Hashtable @{ a = 1; b = 2; c = 3 } @{ b = 2; c = 4; e = 5}

### EXAMPLE 2
```
" 5) and g (6 "<=").
```

$left = @{ a = 1; b = 2; c = 3; f = $Null; g = 6 }
$right = @{ b = 2; c = 4; e = 5; f = $Null; g = $Null }
Compare-Hashtable $left $right

## PARAMETERS

### -Left
The left hand side Hashtable to compare.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Right
The right hand side Hashtable to compare.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
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
