package curl_download;

use strict;
use urpm::download;

our $VERSION = '1.2';

sub readproxy (;$) {
    my $proxy = get_proxy($_[0]);
    ($proxy->{http_proxy} || $proxy->{ftp_proxy} || '',
	defined $proxy->{user} ? "$proxy->{user}:$proxy->{pwd}" : '');
}

sub writeproxy {
    my ($proxy, $proxy_user, $o_media_name) = @_;
    my ($user, $pwd) = split /:/, $proxy_user;
    set_proxy_config(user => $user, $o_media_name);
    set_proxy_config(pwd => $pwd, $o_media_name);
    set_proxy_config(http_proxy => $proxy, $o_media_name);
    set_proxy_config(ftp_proxy => $proxy, $o_media_name);
    dump_proxy_config();
}

1;
