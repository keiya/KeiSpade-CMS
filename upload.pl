#!/usr/bin/perl

use strict;
use CGI;
use File::Copy;
use lib './lib';


my $buffer;
my $query = CGI->new;
my $fh    = $query->upload('file') or die(qq(Invalid file handle returned.)); # Get $fh
my $file  = $query->param('file');
my $back = $query->param('backpage');

        my $tmp = $ENV{'REMOTE_ADDR'}.time;
        #my $file_name = ($file =~ /([^\\\/:]+)$/) ? $1 : 'uploaded.bin';
        #sha2()
        open(OUT, ">/tmp/$tmp") or die(qq(Can't open "$tmp".));
        binmode OUT;
        while (read($fh, $buffer, 1024)) { # Read from $fh insted of $file
            print OUT $buffer;
        }
        close OUT;
        require Digest::SHA::PurePerl;
        my $sha = Digest::SHA::PurePerl->new(256);
        $file =~ m/\.([\d\w]+)$/;
        my $ext = $1;
        $sha->addfile('/tmp/'.$tmp);
        my $filename = $sha->hexdigest;
        move( '/tmp/'.$tmp, './files/'.$filename.'.'.$ext);

print $query->redirect("index.pl?cmd=addfile&page=$back&filename=$filename.$ext&orig=$file");
