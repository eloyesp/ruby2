#!/bin/sh

pandoc -t slidy -s presentation.markdown -o presentation.html && firefox presentation.html
