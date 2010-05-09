#!/usr/bin/perl

use strict;
use CGI;
use File::Copy;
use lib './lib';


print $query->redirect("index.pl?cmd=addfile&page=$back&filename=$filename.$ext&orig=$file");

