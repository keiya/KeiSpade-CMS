# ------------------------------------------------------------------------
#   ajaxcom.cgi ---- Ajax comment component (CGI)
#   Copyright 2005-2006 Kawasaki Yusuke <u-suke [at] kawa.net>
#   http://www.kawa.net/works/ajax/ajaxcom/ajaxcom.html
# ------------------------------------------------------------------------
    use strict;
    use CGI;
    require "misclib.pl";
# ------------------------------------------------------------------------
    my $AJAXCOM_DATA = "./ajaxcom-data";
# ------------------------------------------------------------------------
    &ajaxcom_main();
# ------------------------------------------------------------------------
sub ajaxcom_main {
    my $cgi = new CGI();

    my $name = $cgi->param("name");
    my $content = $cgi->param("content");
    &misclib::tb_err_response( "name is null" ) if ( $name eq "" );
    &misclib::tb_err_response( "content is null" ) if ( $content eq "" );

    my $file = &misclib::get_log_filename( $AJAXCOM_DATA );
    &misclib::tb_err_response( "invalid service url" ) unless defined $file;

    my $date = &misclib::get_w3cdtf_date();
	#my $iphash = &misclib::get_ipaddr_hash();
    my $ipaddr = $ENV{REMOTE_ADDR} or 'undef';
    my $line = [ $date, $$, $ipaddr, $name, $content ];
    my $werror = &misclib::write_tab_line( $file, $line );
    &misclib::tb_err_response( $werror ) if defined $werror;

	#&ajaxcom_update_rss();

    &misclib::tb_ok_response();
}
# ----------------------------------------------------------------
;1;
# ------------------------------------------------------------------------
