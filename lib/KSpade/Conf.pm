#
# KeiSpade CMS (configuration file load script) Perl SubScript
# Version 1.0.1
# スペースをデリミタとしたキーバリュー型の設定ファイルをロードし、ハッシュに格納します。
#
# usage 
# %hash = &kscconf::load
#
# Written by Keiya CHINEN <keiya_21@yahoo.co.jp>
# 
# KSCCONF

package KSpade::Conf;

sub load {
	my %HASH;
	if (-r $_[0]) {
		open(CONF,$_[0]) || die("$0: Unable to load config file ($_[0]): $!\n");
		while (<CONF>) {
			chomp;
			next if /^#/ || /^$/;
			my ($key,$value) = split(/\s/,$_,2);
			$HASH{$key} = $value;
		}
		close(CONF);
	}	
	return %HASH;
}

1;

