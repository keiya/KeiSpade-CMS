package sql;

sub fetch {
	my $dbh = DBI->connect($_[1]);
	my $sth = $dbh->prepare($_[0]);
	my $rv = $sth->execute;
	my @row;
#	print "SQL COMMAND: [$_[0]] from table '$_[1]'<br />";
	my $i = 0;
	while ( my $arr_ref = $sth->fetchrow_arrayref ){
		if (defined $_[2]) {
			push(@row, (@$arr_ref)[$_[2]]);
		} else {
			@row = @$arr_ref; 
		}
	} continue {
			$i++;
	}
	#my $arr_ref = $sth->fetchrow_arrayref;
	#@row = @$arr_ref; 
	$sth->finish;
	$dbh->disconnect;
	return(@row);
}

sub do {
	my $dbh = DBI->connect($_[1]);
	$dbh->do($_[0]);
	$dbh->disconnect;
	return 1;
}

sub create_table {
	#my $dbh = DBI->connect($data_source);
       	$notable = 1;
       	my $dbh = DBI->connect($_[0]);
       	my $create_table = "create table pages (" .
       	                       "title," .
       	                       "lastmodified_date," .
       	                       "created_date," .
       	                       "tags," .
       	                       "autotags," .
       	                       "confer," .
       	                       "copyright," .
                              "body" .
       	                   ");";
       	$dbh->do($create_table);
       	$dbh->disconnect;
}

sub tableexists {
	my $dbh = DBI->connect($_[0]);
	# なかったらテーブルつくる
	my @res = &fetch("select count(*) from sqlite_master where type='table' and name='pages';",$_[0]);
	return $res[0];
}

1;
