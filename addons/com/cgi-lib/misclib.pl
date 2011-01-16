#!/usr/bin/perl
# ----------------------------------------------------------------
#   misclib.pl ---- misc functions for ajax's server side
#   Copyright 2005-2006 Kawasaki Yusuke <u-suke [at] kawa.net>
#   http://www.kawa.net/
# ----------------------------------------------------------------
    package misclib;
    use strict;
    use XML::TreePP;
# ------------------------------------------------------------------------
sub output_feed_rss {
    my $feed = shift;
    my $file = shift;
    open( OUT, "> $file" ) or return;
    print OUT $feed->to_string();
    close( OUT );
    chmod( 0666, $file );
    $file;
}
# ------------------------------------------------------------------------
sub output_feed_json {
    my $feed = shift;
    my $file = shift;
    my $json = &json_dump( $feed ) or return;
    open( OUT, "> $file" ) or return;
    print OUT $json;
    close( OUT );
    chmod( 0666, $file );
    $file;
}
# ------------------------------------------------------------------------
sub json_dump {
    my $data = shift;
    return JSON::Syck::Dump($data) if defined $JSON::Syck::VERSION;
    return JSON->new()->objToJson($data) if defined $JSON::VERSION;
    local $@;
    eval { require JSON::Syck; };
    return JSON::Syck::Dump($data) if defined $JSON::Syck::VERSION;
    eval { require JSON; };
    return JSON->new()->objToJson($data) if defined $JSON::VERSION;
    undef;
}
# ----------------------------------------------------------------
sub find_recent_lines {
    my $basedir = shift or return;
    my $max_total = shift || 100;   # limit in total
    my $max_page  = shift ||  10;   # limit each page
    my $sorted = &find_all_files( $basedir );
    $#$sorted = $max_total-1 if ( $#$sorted >= $max_total );

    my $bufline = [];
    foreach my $text ( @$sorted ) {
        my $file = "$basedir/$text";
        my $buftail = [];
        open( TEXT, $file ) or die "$! - $file\n";
        while ( my $iline = <TEXT> ) {
            unshift( @$buftail, $iline );
            $#$buftail = $max_page-1 if ( $#$buftail >= $max_page );
        }
        close( TEXT );
        my $addlist = [ map { [$text,$_] } @$buftail ];
        $bufline = [ sort {$b->[1] cmp $a->[1]} ( @$bufline, @$addlist ) ];
        $#$bufline = $max_total-1 if ( $#$bufline >= $max_total );
    }

    $bufline;
}
# ----------------------------------------------------------------
sub find_all_files {
    my $base = shift;
    my $alltxt = [];
    opendir( DIR, $base ) or die "$! - $base\n";
    while( my $text = readdir(DIR) ) {
        next unless ( $text =~ m#([^/]+)\.txt$# );
        push( @$alltxt, $text );
    }
    close( DIR );
    my $modate = { map {$_ => -M "$base/$_"} @$alltxt };
    my $sorted = [ sort {$modate->{$a} <=> $modate->{$b}} @$alltxt ];
    $sorted;
}
# ------------------------------------------------------------------------
sub pack_query_string {
    my $query = shift;
    my $array = [];
    foreach my $key ( sort keys %$query ) {
        my $val = $query->{$key};
        $key =~ s/([^\w\-\.\,\/])/sprintf("%%%02X",ord($1))/ges;
        $val =~ s/([^\w\-\.\,\/])/sprintf("%%%02X",ord($1))/ges;
        push( @$array, "$key=$val" );
    }
    my $vars = join( "&", @$array );
    $vars;
}
# ------------------------------------------------------------------------
sub get_log_filename {
    my $base = shift;
    my $src = $ENV{PATH_INFO};
    $src =~ s#///*#/#;              # multiple /
    $src =~ s#/((index|default).(s?html?|asp|cgi|php))?$##;
    $src =~ s#^/##;                 # first /
    $src =~ s#/$##;                 # last /
    $src = "/" if ( $src eq "" );   # root /
    my $path = &check_url_alias( $base, $src );
    sprintf( "%s/%s.txt", $base, $path );
}
# ------------------------------------------------------------------------
sub check_url_alias {
    my $base = shift;
    my $url = shift;
    my $alias = &read_url_alias( $base );
    return $alias->{$url} if ( ref $alias && $alias->{$url} );
    my $aliasfile = sprintf( "%s/url.alias", $base );
    my $file = $url;
    $file =~ s/[^A-Za-z0-9\-\_\.]/_/g;
    open( LIST, ">> $aliasfile" ) or return;
    print LIST $file, "\t", $url, "\n";
    close( LIST );
    chmod( 0666, $aliasfile );
    $file;
}
# ----------------------------------------------------------------
sub read_url_alias {
    my $base = shift;
    my $aliasfile = sprintf( "%s/url.alias", $base );
    open( LIST, $aliasfile ) or return;
    my $map = {};
    while ( my $line = <LIST> ) {
        next if ( $line =~ /^#/ );
		chomp $line;
        my( $file, $url ) = split( /\s+/, $line );
        $map->{$url} = $file;
    }
    close( LIST );
    $map;
}
# ------------------------------------------------------------------------
#   write a tab-separated line
# ------------------------------------------------------------------------
sub write_tab_line {
    my $file = shift;
    my $array = shift;
    foreach my $str ( @$array ) {
        $str =~ s/\s+/ /sg;
    }
    open( LOG, ">> $file" ) or return "$! - $file\n";
    my $text = join( "\t", @$array );
    print LOG $text, "\n";
    close( LOG );
    local $!;
    chmod( 0666, $file );
    undef;              # ok
}
# ------------------------------------------------------------------------
#   W3C's Date and Time Formats
#   http://www.w3.org/TR/NOTE-datetime
# ------------------------------------------------------------------------
sub get_w3cdtf_date {
    my $epoch = shift || time();
    my( $sec, $min, $hour, $day, $mon, $year ) = gmtime( $epoch );
    $year += 1900;
    $mon ++;
    sprintf( "%04d-%02d-%02dT%02d:%02d:%02dZ",
        $year, $mon, $day, $hour, $min, $sec );
}
# ----------------------------------------------------------------
#   hash value of remote IP address (10000-9999)
# ----------------------------------------------------------------
sub get_ipaddr_hash {
    my $ipaddr = $ENV{REMOTE_ADDR} or return;
    my $intaddr = unpack( N => pack( C4 => reverse split( /\./, $ipaddr )));
    my $hashval = 10000 + $intaddr % 90000;
    $hashval;
}
# ----------------------------------------------------------------
#   redirect to another url
# ----------------------------------------------------------------
sub redirect {
    my $url = shift;
    print "Location: ", $url, "\n\n";
    exit();
}
# ----------------------------------------------------------------
#   trackback's error response
#   http://www.sixapart.jp/movabletype/manual/mttrackback.html
# ----------------------------------------------------------------
sub tb_err_response {
    my $message = shift;
    my $tree = {
        response    =>  {
            error   =>  1,
            message =>  $message,
        },
    };
    &output_xml( $tree );
}
# ----------------------------------------------------------------
#   trackback's ok response
# ----------------------------------------------------------------
sub tb_ok_response {
    my $tree = {
        response    =>  {
            error   =>  0,
        },
    };
    &output_xml( $tree );
}
# ----------------------------------------------------------------
#   output xml source
# ----------------------------------------------------------------
sub output_xml {
    my $tree = shift;
    my $tpp = XML::TreePP->new();
    my $xml = $tpp->write( $tree );
    print "Content-Length: ", length($xml), "\n";
    print "Content-Type: text/xml; charset=UTF-8\n";
    print "\n";
    print $xml;
    exit();
}
# ----------------------------------------------------------------
sub encode_from_to {
    my( $str, $from, $to ) = @_;
    return if ( $from eq "" );
    return if ( $to eq "" );
    return $to if ( uc($from) eq uc($to) );
    local $@;
    eval { require Encode; } unless defined $Encode::VERSION;
    if ( defined $Encode::VERSION ) {
        Encode::from_to( $$str, $from, $to, Encode::FB_XMLCREF() );
    } elsif (( uc($from) eq "ISO-8859-1" || uc($from) eq "US-ASCII" ||
               uc($from) eq "LATIN-1" ) && uc($to) eq "UTF-8" ) {
        &latin1_to_utf8( $str );
    } else {
        my $jfrom = &get_jcode_name( $from );
        my $jto   = &get_jcode_name( $to );
        return $to if ( uc($jfrom) eq uc($jto) );
        if ( $jfrom && $jto ) {
            eval { require Jcode; } unless defined $Jcode::VERSION;
            if ( defined $Jcode::VERSION ) {
                Jcode::convert( $str, $jto, $jfrom );
            } else {
                die "Encode.pm or Jcode.pm is required: $from to $to";
            }
        } else {
            die "Encode.pm is required: $from to $to";
        }
    }
    $to;
}
# ----------------------------------------------------------------
sub latin1_to_utf8 {
    my $strref = shift;
    $$strref =~ s{
        ([\x80-\xFF])
    }{
        pack( "C2" => 0xC0|(ord($1)>>6),0x80|(ord($1)&0x3F) )
    }exg;
}
# ----------------------------------------------------------------
sub get_jcode_name {
    my $src = shift;
    my $dst;
    if ( $src =~ /^utf-?8$/i ) {
        $dst = "utf8";
    } elsif ( $src =~ /^euc.*jp$/i ) {
        $dst = "euc";
    } elsif ( $src =~ /^(shift.*jis|cp932|windows-31j)$/i ) {
        $dst = "sjis";
    } elsif ( $src =~ /^iso-2022-jp/ ) {
        $dst = "jis";
    }
    $dst;
}
# ----------------------------------------------------------------
;1;
# ----------------------------------------------------------------
