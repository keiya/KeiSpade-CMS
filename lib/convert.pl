package convert;

sub tohtml {
my $syntax = $_[0];
$$syntax =~ s/^\s*|\s*$//gs;
$$syntax .= "\n";
my @list;
$$syntax =~ s{^(.*)\n} {
my $markup;
my $match = $1;
$match =~ m/^([\*-+])/;
if ($match =~ /^(\*+)(.+?)$/) {
my $tag = $1;
my $element = $2;
		my $hcnt = $tag =~ tr/\*/\*/;
		if ($hcnt == 1) {
			$markup = "<h3>$element</h3>";
		} elsif ($hcnt == 2) {
			$markup = "<h4>$element</h4>";
		} elsif ($hcnt == 3) {
			$markup = "<h5>$element</h5>";
		}
} elsif ($match =~ /\[p:(.+)\]/){
my $img = $1;
$img =~ m/(.+)\s(\d+?)x(\d+?)$/;
$markup = "<a href=\"$1\" target=\"KeiSpade_img\"><img src=\"$1\" alt=\"$1\" width=\"$2\" height=\"$3\"></a>";
} elsif ($match =~ /\[v:(.+)\]/) {
$markup = "<video src=\"$1\" controls=\"controls\" preload=\"preload\"><a href=\"$1\">Link to this Video</a></video>";

} elsif ($match =~ /^(-+|\++)(.+?)$/) {

#push (@list, "$match");
$markup = $match."<br />";
} else {
$markup = $match."<br />";
}
$markup;
}egm;
#return $syntax;
}


sub tohtmlold {
my $syntax = $_[0];

$syntax =~ s/^\s*|\s*$//gs;
$syntax .= "\n";
my $markup;
my $lastnestsdepth=0;
my $nestscnt=0;
my $lasttag;


		my $depth;
$syntax =~ s{^(.*)\n}{
	my $match =  $1;
	
	$match =~ m/^([\*-+]+)/;
	$nests = $1;
	$nestscnt = $nests =~ tr/-+\*//;
	if ($match =~ /^(\*+)(.+?)$/) {
		my $element = $2;
		my $headline = $1;
		my $hcnt = $headline =~ tr/\*/\*/;
		if ($hcnt == 1) {
			$markup = "<h3>$element</h3>";
		} elsif ($hcnt == 2) {
			$markup = "<h4>$element</h4>";
		} elsif ($hcnt == 3) {
			$markup = "<h5>$element</h5>";
		}
	}
	
	elsif ($match =~ /^(-+|\++)(.+?)$/) {
		my $tag;
		my $element = $2;
		if ($1 =~ /-/) {
			$tag = 'ul';
		} elsif ($1 =~ /\+/) {
			$tag = 'ol';
		}
	$markup = "<!-- $depth  -->";
#	print "($nestscnt - $lastnestsdepth \@ $element) ";
		if ($nestscnt > $lastnestsdepth) {
			$depth++;
			#if ($depth > 1) {
			$markup = "<$tag><li>$element</li>";
                        $markup .= "<!-- ←1 : $depth : $nestscnt -->";
#}
		} elsif ($nestscnt < $lastnestsdepth) {
                        $depth--;
#			if ($depth - $nestscnt > 1) {
			$markup = "</$tag><li>$element</li>";
                        $markup .= "<!-- ←2 : $depth : $nestscnt -->";
#			}
		} elsif ($nestscnt == $lastnestsdepth) {
			$markup = "<li>$element</li>";
                        $markup .= "<!-- ←3 : $depth : $nestscnt -->";
		}
		$lastnestsdepth = $nestscnt;
		$lasttag = "$tag";
	}
	
	elsif ($match =~ /^(&gt;&gt|&lt;&lt;)/) {
		my $subs = $match;
		$subs =~ s/&gt;&gt;/<blockquote>/;
		$subs =~ s/&lt;&lt;/<\/blockquote>/;
		$markup = $subs;
	}

	else {
#	print "($nestscnt - $lastnestsdepth \@ $match) ";
		if ($nestscnt == 0 and $lastnestsdepth >0) {
			while ($lastnestsdepth > 0) {
				$tmp .= "</$lasttag>";
			} continue {
				$lastnestsdepth--;
			}
			$markup = $tmp.$match;
		} else {
		$markup = $match;
		}
	$markup .= "<br />";
	}
	$markup;
}egm;
return $syntax;
}

1;
