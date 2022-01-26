#!/bin/bash

FILENAME=`grep value main.md | head -1 | cut -d'"' -f2`

mmark main.md > $FILENAME.xml
`which xml2rfc` --html $FILENAME.xml
`which xml2rfc` --text $FILENAME.xml

