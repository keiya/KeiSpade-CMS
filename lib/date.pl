

#
# Yoyaku.in (misc script) Utility Perl Script
# Version 1.0.0 alpha
# some useful subroutine

package date;

# 現在の日付時刻を取得し，引数の書式に整形した上で返却
sub spridate {
    my ($sec, $min, $hour, $day, $mon, $year) = (localtime (time))[0,1,2,3,4,5];
    $year = $year + 1900;
    $mon = $mon + 1;
    return sprintf($_[0], $year, $mon, $day, $hour, $min, $sec);
}

sub spridatearg {
    my ($day, $mon, $year) = (localtime ($_[1]))[3,4,5];
    $year = $year + 1900;
    $mon = $mon + 1;
    return sprintf($_[0], $year, $mon, $day);
}

sub spritimearg {
    my ($sec, $min, $hour) = (localtime ($_[1]))[0,1,2];
    return sprintf($_[0], $hour, $min, $sec);
}
1;

