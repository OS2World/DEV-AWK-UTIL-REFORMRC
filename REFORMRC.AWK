#   REFORMRC.AWK - Script to convert a .RC file into a clearer form
#
#   (c) Copyright 1991 Software Architects, Inc.  All Rights Reserved.
#
#   Written by: Guy Scharf
#               Software Architects, Inc.
#               2163 Jardin Drive
#               Mountain View, CA   94040
#               (415) 948-9186
#               FAX: (415) 948-1620
#               CompuServe 76702,557
#   
#   Changes generic CONTROL statements to more specific RC statements
#
#   This program reformats a .RC or .DLG file as produced by the dialog
#   box editor or CASE:PM.  It is dependent on the line formatting used
#   by these tools.  It will not reformat hand-written .RC files with
#   different line ending conventions.  It cannot be run recursively.
#
#   As an awk script, this program is simply a line reformatted.  It does
#   not contain a .RC language syntax scanner.
#
#   Permission is granted to use this script and to modify it.  Software
#   Architects, Inc. accepts no responsibility for the result.  I.e.,
#   this software is supplied "AS IS" and you bear all the responsibility
#   of making sure it does what you want.
#
#   We would appreciate your sending us any changes that improve the
#   program.
#
#   NOTE: REFORMRC.AWK is an internal Software Architects, Inc. tool and
#         is an envolving work in progress. It is not complete nor does
#         it handle all situations.  It is supposed to pass through things
#         it does not recognized unscathed, but this is not guaranteed.
#         I.e., Keep a backup of your .RC file!
#
#         I expect someday to rewrite this as a more intelligent REXX program.
#
#   Usage:
#
#       awk -f reformrc.awk program.rc >newprog.rc
#
#       After running awk, search for "***" in the output file, which
#       will mark any errors.  Program may get confused if there are
#       commas in any text strings.  
#
#       This program has been tested with PolyAWK and MKS AWK.
#
#   History:
#       07/31/91: o Go back to PUSHBUTTON statements and use NOT clauses
#                   to eliminate unwanted defaults.
#       06/23/91: o Changed COMBOBOX to new format (disagrees with IBM
#                   PT&I documentation, but it works, and APARs have
#                   been issued against documentation).
#                 o Don't convert ICON control statement.  It does not
#                   work reliably, and IBM and MS disagree on format.
#                 o Revise PUSHBUTTON handling to better match CUA.
#                   Leave them as CONTROL statements, set WS_TABSTOP
#                   on the first one, but not on any others.  Also
#                   set WS_GROUP on first one.
#                 o Format CONTROL statements that do not get changed
#                   into another statement.
#
############################

#
#   Look for MENU statements and try to line them up
#
/ MENUITEM | SUBMENU | HELPITEM | HELPSUBITEM / {

    if ($1 == "MENUITEM" || $1 == "SUBMENU" || $1 == "HELPITEM" || $1 == "HELPSUBITEM")
    {
        indval = index($0,$1)
        indspl = index(substr($0,indval), " ")

        nfields = split (substr($0,indval+indspl), arr, ",")
        
        text = trim(arr[1])
        id = trim(arr[2])
        type = trim(arr[3])
        extra = ""
        for (i=4; i <=nfields; i++)
        {
            if (extra != "")
                extra = extra + ", "
            extra = extra trim(arr[i])
        }
        indval = index($0,$1)
        outline = ""
        for (i=1; i<=indval; i++)
            outline = outline " "
        outline = outline $1 "  " text
        if (text == "SEPARATOR")
        {
            print outline
            next
        }
        outline = outline ", "
        if ($1 == "MENUITEM")
            indset = indval+35
        else if ($1 == "HELPSUBITEM")
            indset = indval+40
        else
            indset = indval+20
        while (length(outline) > indset)
            indset += 5
        while (length(outline)<indset)
            outline = outline " "

        outline = outline id
        if (type != "")
            outline = outline ", "

        while (length(outline)<(indset+15))
            outline = outline " "
        outline = outline type
        if (extra != "")
            outline = outline ", " extra
        print outline
        next
    }
        }

#
#   Mark beginning of new dialog template
#
/^DLGTEMPLATE/  {
                    firstpush = 1
                }


#
#       Look for CONTROL statements
#

{
    if (NF == 0)
    {
        print $0
        next
    }

    if ($1 != "CONTROL")
    {
        print $0
        next
    }

    ctl = $0

#
#   Read in all lines of the CONTROL statement, concatenating them
#
    while (substr(ctl,length(ctl),1) == " ")
    {
        ctl = substr(ctl,1, length(ctl)-1)
    }

    while ((substr(ctl,length(ctl),1) == ",") || (substr(ctl,length(ctl),1) == "|") )
    {
        getline
        ctl = ctl $0
        while (substr(ctl,length(ctl),1) == " ")
        {
            ctl = substr(ctl,1, length(ctl)-1)
        }
    }

#
#   Parse the CONTROL statement
#
    nfields = split (ctl, arr, ",")

    if (nfields != 8)
    {
        print "*** Wrong number of fields found, got "  nfields
        print ctl
        next
    }

    startfmt = "%s%-11s "

    i = index(arr[1], "CONTROL ")
    blankhdr = substr(arr[1], 1, i-1)
    arr[1] = substr(arr[1], i+8)

    for (i = 1; i <= 8; i++)
    {
        while (substr(arr[i],1,1) == " ")
            arr[i] = substr(arr[i],2)
        while (substr(arr[i],length(arr[i]),1) == " ")
            arr[i] = substr(arr[i],1,length(arr[i])-1)
    }
    textstr = arr[1]
    id      = arr[2]
    x       = arr[3]
    y       = arr[4]
    cx      = arr[5]
    cy      = arr[6]
    class   = arr[7]
    style   = arr[8]

#
#   Split the control styles up into an array
#
    nstyles = split (style, astyle, "|")
    for (i = 1; i <= nstyles; i++)
    {
        while (substr(astyle[i],1,1) == " ")
            astyle[i] = substr(astyle[i],2)
        while (substr(astyle[i],length(astyle[i]),1) == " ")
            astyle[i] = substr(astyle[i],1,length(astyle[i])-1)
    }

#   print "textstr   = " textstr
#   print "id        = " id
#   print "x,y,cx,cy = " x ", " y ", " cx ", " cy
#   print "class     = " class
#   print "style     = " style

#
#   Examine each CONTROL type and construct fields to build
#   the new .RC statement for the specific control class
#   identified.
#
    doclass = 0

    if ((index(class, "WC_BUTTON") > 0) && (index(style, "BS_PUSHBUTTON") > 0))
    {
        if (index(style, "BS_DEFAULT") > 0)
        {
            key = "DEFPUSHBUTTON"
            if (length(blankhdr) >= 3)
            {
                blankhdr = substr(blankhdr,4)
                startfmt = "%s%-14s "
            }
        }
        else
            key = "PUSHBUTTON"

#       key = "CONTROL"
#
        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "BS_PUSHBUTTON") >= 1)
                continue
            if (index(astyle[i], "BS_DEFAULT") >= 1)
                continue
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue
            if (index(astyle[i], "WS_GROUP") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        if (firstpush)
        {
            firstpush = 0
            if (newstyle != "")
                newstyle = newstyle " | WS_GROUP "
            else
                newstyle = " WS_GROUP "
        }
        else
            if (newstyle != "")
                newstyle = newstyle " | NOT WS_TABSTOP "
            else
                newstyle = " NOT WS_TABSTOP "

        dotext = 1
#       doclass = 1

        emit()
    }
    else if ((index(class, "WC_BUTTON") > 0) && (index(style, "BS_AUTOCHECKBOX") > 0))
    {
        key = "AUTOCHECKBOX"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "BS_AUTOCHECKBOX") >= 1)
                continue
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_BUTTON") > 0) && (index(style, "BS_CHECKBOX") > 0))
    {
        key = "CHECKBOX"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "BS_CHECKBOX") >= 1)
                continue
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_STATIC") > 0) && (index(style, "DT_LEFT") > 0))
    {
        key = "LTEXT"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "DT_LEFT") >= 1)
                continue                 
            if (index(astyle[i], "SS_TEXT") >= 1)
                continue                 
            if (index(astyle[i], "WS_GROUP") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_STATIC") > 0) && (index(style, "DT_RIGHT") > 0))
    {
        key = "RTEXT"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "DT_RIGHT") >= 1)
                continue                 
            if (index(astyle[i], "SS_TEXT") >= 1)
                continue                 
            if (index(astyle[i], "WS_GROUP") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_STATIC") > 0) && (index(style, "DT_CENTER") > 0))
    {
        key = "CTEXT"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "DT_CENTER") >= 1)
                continue                 
            if (index(astyle[i], "SS_TEXT") >= 1)
                continue                 
            if (index(astyle[i], "WS_GROUP") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_STATIC") > 0) && (index(style, "SS_GROUPBOX") > 0))
    {
        key = "GROUPBOX"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "SS_GROUPBOX") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_STATIC") > 0) && (index(style, "SS_ICON") > 0))
    {
#        key = "ICON"
        key = "CONTROL"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1
        doclass = 1

        emit()
    }
    else if (index(class, "WC_LISTBOX") > 0) 
    {
        key = "LISTBOX"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "WS_GROUP") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 0

        emit()
    }
    else if (index(class, "WC_ENTRYFIELD") > 0) 
    {
        key = "ENTRYFIELD"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "WS_GROUP") >= 1)
                continue                 
            if (index(astyle[i], "ES_AUTOSCROLL") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if (index(class, "WC_COMBOBOX") > 0) 
    {
        key = "COMBOBOX"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "WS_GROUP") >= 1)
                continue                 
            if (index(astyle[i], "CBS_SIMPLE") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_BUTTON") > 0) && (index(style, "BS_AUTORADIOBUTTON") > 0))
    {
        key = "AUTORADIOBUTTON"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "BS_AUTORADIOBUTTON") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }
    else if ((index(class, "WC_BUTTON") > 0) && (index(style, "BS_RADIOBUTTON") > 0))
    {
        key = "RADIOBUTTON"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (index(astyle[i], "BS_RADIOBUTTON") >= 1)
                continue                 
            if (index(astyle[i], "WS_TABSTOP") >= 1)
                continue
            if (index(astyle[i], "WS_VISIBLE") >= 1)
                continue

            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1

        emit()
    }

    else
    {
        key = "CONTROL"

        newstyle = ""

        for (i=1; i <=nstyles; i++)
        {
            if (newstyle != "")
                newstyle = newstyle " | "
            newstyle = newstyle astyle[i]
        }

        dotext = 1
        doclass = 1

        emit()
    }
}


#
#   EMIT creates the output statement from parsed and evaluated input
#
function emit()
{
    outline = sprintf(startfmt, blankhdr, key)

    if (dotext == 1)
    {
        outline = outline sprintf("%s, ", textstr)
    }

    indval = length(outline)
    while (indval<35)
    {
        outline = outline " "
        indval++
    }
    outline = outline sprintf("%s, ", id)

    indval = length(outline)

    if (indval > 45)
    {
        print outline
        outline = "                                        "
        indval = length(outline)
    }
    while (indval<45)
    {
        outline = outline " "
        indval++
    }

    outline = outline sprintf("%4s, %4s, %4s, %4s", trim(x), trim(y), trim(cx), trim(cy))
    if (doclass)
    {
        outline = outline sprintf(", %s", class)
    }

    if (newstyle != "")
    {
        outline = outline ", "
        firststyle = 1

        nstyles = split (newstyle, astyle, "|")

        for (i=1; i <=nstyles; i++)
        {
            if (firststyle == 1)
                firststyle = 0
            else
                outline = outline " |"

            if (length(outline) > 75)
            {
                printf("%s\n", outline)
                outline = "                   "
            }

            if (substr(astyle[i],1,1) == " ")
                astyle[i] = substr(astyle[i],2)

            outline = outline " " astyle[i]
        }
    }

    if (length(outline) > 0)
        printf("%s\n",outline)

#   printf(startfmt, blankhdr, key)
#
#   if (dotext == 1)
#       printf("%s, ", textstr)
#
#   printf("%s, %s, %s, %s, %s", id, x, y, cx, cy)
#
#   if (newstyle != "")
#       printf(", %s", newstyle)
#   printf("\n")
    return 
}

function trim(val)
{
    while (substr(val,1,1) == " ")
        val = substr(val,2)
    while (substr(val,length(val),1) == " ")
        val = substr(val,length(val)-1)
    return val
}

