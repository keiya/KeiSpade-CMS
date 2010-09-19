package Ksp::Edit;

use strict;

# ページ編集・作成用共通サブルーチン
sub fetch2edit {
	my $class = shift;
	my @elements = shift;
	my ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body) = ('','','','','','','','');
	read (STDIN, my $postdata, $ENV{'CONTENT_LENGTH'});
	my %form = &cgidec::getline($postdata);
	$body = &security::exorcism($form{'body'});
	my $bodyhash = &security::exorcism($form{'bodyhash'});
	$title = &security::textalize(&security::exorcism($form{'title'}));

	my $tagstr = $title;
	if (defined $tagstr) {
	$tagstr =~ s/^\[(.+)\](.+)/$1/g;
	if (defined $2) {
		my @tagstrs= split(/\]\[/, $tagstr);
		foreach my $tag (@tagstrs) {
			$tag =~ s/[\[\]]+//g;
			$tags .= $tag.'|';
		}
	}
	}
	$modified_date = time();
	$created_date = time();

	chomp ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body,$bodyhash);
	return ($title,$modified_date,$created_date,$tags,$autotags,$confer,$copyright,$body,$bodyhash);
}

1;
