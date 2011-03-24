#!/usr/bin/perl
use strict;
use CGI;
use File::Copy;
use File::Temp qw/ tempfile /;
use lib '../../lib';
use KSpade::Conf;

my ($buffer,$filesize);
my $query = CGI->new;
my $fh = $query->upload('file') or die(qq(Invalid file handle returned.)); # Get $fh
my $file = $query->param('file');
my $back = $query->param('backpage');
my %vars;
$vars{'ScriptName'} = 'index.pl';
$vars{'Addons::upl::FileDir'} = '../../dat/page/files/';
%vars = (%vars,KSpade::Conf::load('./dat/kspade.conf'));
my $scriptname = $vars{'ScriptName'};

#my $tmp = $ENV{'REMOTE_ADDR'}.time;
#my $file_name = ($file =~ /([^\\\/:]+)$/) ? $1 : 'uploaded.bin';
#sha2()

if (!-d $vars{'Addons::upl::FileDir'}) {
	mkdir $vars{'Addons::upl::FileDir'} or 
	warn "[KeiSpade-CMS] Directory '". $vars{'Addons::upl::FileDir'} ." not found. Please mkdir.";
}

my($tmp_fh, $tmpfile) = tempfile(UNLINK => 1);
binmode $tmp_fh;
while (read($fh, $buffer, 1024)) { # Read from $fh insted of $file
	print $tmp_fh $buffer;
}
close $tmp_fh;
close $fh;
$filesize = -s $tmpfile;

# Ext. check
$file =~ s/\.php3?//g;
$file =~ s/\.phtml//g;
$file =~ m/\.([\d\w]+)$/;
my $ext = $1;

# delimiter
$file =~ s/[\[\]\/]+//g;

my $filename = &sha($tmpfile);

my $writeto = $vars{'Addons::upl::FileDir'}.$filename.'.'.$ext;
if (!move( $tmpfile, $writeto)) {
	warn "[KeiSpade-CMS] Cannot write to $writeto. Please check permission.";
}

print <<_HTML_;
Content-type: text/html


<html>
<head>
<title>fileupload</title>
<!-- ファイル情報を表示する関数の呼び出し -->
<script type="text/javascript"><!--
var fname="$file";
var fsize="$filesize";
window.onload=function(){
		window.parent.GetFile(fname,fsize);
		location.href="../../$scriptname?adon=upl&acmd=addfile&page=$back&filename=$filename.$ext&orig=$file";
}
--></script>
</head>
<body><p>fileupload</p></body>
</html>
_HTML_


#print $query->redirect( "$scriptname?cmd=addfile&page=$back&filename=$filename.$ext&orig=$file");
sub sha {
	my $file = $_[0];
	$file =~ s/|//g;
	$file =~ s/`//g;
	my $sha;
	if (open(SHA1SUM, "sha256sum $file |")) {
		my $tmp;
		while (<SHA1SUM>) {
			$tmp .= $_;
		}
		$tmp =~ s/[\n\r]+//g;
		chomp $tmp;
		$sha = $tmp;
		$sha =~ m/([\w\d]+)/;
		$sha = $1;
		close(SHA1SUM);
		if ($?) {
			$sha = &shaperl($file);
		}
	} else {
		$sha = &shaperl($file);
	}
	return $sha;
}

sub shaperl {
	require Digest::SHA::PurePerl;
	my $sha = Digest::SHA::PurePerl->new(256);
	return $sha->add($_[0])->hexdigest;
}


