package ManaTools::Shared::RunProgram;

use strict;
use MDK::Common;
use Sys::Syslog;
use MDK::Common::File qw(cat_);

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    set_default_timeout
    run_or_die
    rooted_or_die
    get_stdout
    get_stdout_raw
    rooted_get_stdout
    run
    raw
    rooted
);

=head1 SYNOPSYS

B<rManaTools::Shared::RunProgram> enables to:

=over 4

=item * run programs in foreground or in background,

=item * to retrieve their stdout or stderr

=item * ...

=back

Most functions exits in a normal form & a rooted one. e.g.:

=over 4

=item * C<run()> & C<rooted()>

=item * C<get_stdout()> & C<rooted_get_stdout()>

=back

Most functions exits in a normal form & one that die. e.g.:

=over 4

=item * C<run()> & C<run_or_die()>

=item * C<rooted()> & C<rooted_or_die()>

=back

=head1 Functions

=over

=cut

1;

my $default_timeout = 10 * 60;

=item set_default_timeout($seconds)

Alters defaults timeout (eg for harddrake service)

=cut

sub set_default_timeout {
    my ($seconds) = @_;
    $default_timeout = $seconds;
}

=item run_or_die($name, @args)

Runs $name with @args parameterXs. Dies if it exit code is not 0.

=cut

sub run_or_die {
    my ($name, @args) = @_;
    run($name, @args) or die "$name failed\n";
}

=item rooted_or_die($root, $name, @args)

Similar to run_or_die() but runs in chroot in $root

=cut

sub rooted_or_die {
    my ($root, $name, @args) = @_;
    rooted($root, $name, @args) or die "$name failed\n";
}

=item get_stdout($name, @args)

Similar to run_or_die() but return stdout of program:

=over 4

=item * a list of lines in list context

=item * a string of concatenated lines in scalar context

=back

=cut

sub get_stdout {
    my ($name, @args) = @_;
    my @r;
    run($name, '>', \@r, @args) or return;
    wantarray() ? @r : join('', @r);
}

=item get_stdout_raw($options, $name, @args)

Similar to get_stdout() but allow to pass options to raw()

=cut

sub get_stdout_raw {
    my ($options, $name, @args) = @_;
    my @r;
    raw($options, $name, '>', \@r, @args) or return;
    wantarray() ? @r : join('', @r);
}

=item rooted_get_stdout($root, $name, @args)

Similar to get_stdout() but runs in chroot in $root

=cut

sub rooted_get_stdout {
    my ($root, $name, @args) = @_;
    my @r;
    rooted($root, $name, '>', \@r, @args) or return;
    wantarray() ? @r : join('', @r);
}

=item run($name, @args)

Runs $name with @args parameters.

=cut

sub run {
    raw({}, @_);
}

=item rooted($root, $name, @args)

Similar to run() but runs in chroot in $root

=cut

sub rooted {
    my ($root, $name, @args) = @_;
    raw({ root => $root }, $name, @args);
}

=item raw($options, $name, @args)

The function used by all the other, making every combination possible.
Runs $name with @args parameters. $options is a hash ref that can contains:

=over 4

=item * B<root>: $name will be chrooted in $root prior to run

=item * B<as_user>: $name will be run as $ENV{PKEXEC_UID} or with the UID of parent process. Implies I<setuid>

=item * B<sensitive_arguments>: parameters will be hidden in logs (b/c eg there's a password)

=item * B<detach>: $name will be run in the background. Default is foreground

=item * B<chdir>: $name will be run in a different default directory

=item * B<setuid>: contains a getpwnam(3) struct ; $name will be with droped privileges ;
make sure environment is set right and keep a copy of the X11 cookie

=item * B<timeout>: execution of $name will be aborted after C<timeout> seconds

=item * B<exitcode>: function will return the exit code of the process

=back

eg:

=over 4

=item * C<< ManaTools::Shared::RunProgram::raw({ root => $::prefix, sensitive_arguments => 1 }, "echo -e $user->{password} | cryptsetup luksFormat $device"); >>

=item * C<< ManaTools::Shared::RunProgram::raw({ detach => 1 }, '/etc/rc.d/init.d/dm', '>', '/dev/null', '2>', '/dev/null', 'restart'); >>

=back

=cut

sub raw {
    my ($options, $name, @args) = @_;
    my $root = $options->{root} || '';
    my $real_name = ref($name) ? $name->[0] : $name;

    my ($stdout_raw, $stdout_mode, $stderr_raw, $stderr_mode);
    ($stdout_mode, $stdout_raw, @args) = @args if scalar(@args) >= 2 && $args[0] =~ /^>>?$/;
    ($stderr_mode, $stderr_raw, @args) = @args if scalar(@args) >= 2 && $args[0] =~ /^2>>?$/;

    my $home;
    if ($options->{as_user}) {
        my $uid;
        $uid = $ENV{PKEXEC_UID} && getpwuid($ENV{PKEXEC_UID});
        $uid ||= _get_parent_uid();
        my ($full_user) = grep { $_->[2] eq $uid } list_passwd();
        $options->{setuid} = getpwnam($full_user->[0]) if $full_user->[0];
        $home = $full_user->[7] if $full_user;
    }
    local $ENV{HOME} = $home if $home;

    my $args = $options->{sensitive_arguments} ? '<hidden arguments>' : join(' ', @args);
    Sys::Syslog::syslog('info|local1', "running: $real_name $args" . ($root ? " with root $root" : ""));

    return if $root && $<;

    $root ? ($root .= '/') : ($root = '');

    my $tmpdir = sub {
        my $dir = $< != 0 ? "$ENV{HOME}/tmp" : -d '/root' ? '/root/tmp' : '/tmp';
        -d $dir or mkdir($dir, 0700);
        $dir;
    };
    my $stdout = $stdout_raw && (ref($stdout_raw) ? $tmpdir->() . "/.drakx-stdout.$$" : "$root$stdout_raw");
    my $stderr = $stderr_raw && (ref($stderr_raw) ? $tmpdir->() . "/.drakx-stderr.$$" : "$root$stderr_raw");

    #- checking if binary exist to avoid clobbering stdout file
    my $rname = $real_name =~ /(.*?)[\s\|]/ ? $1 : $real_name;
    if (! ($rname =~ m!^/!
            ? -x "$root$rname" || $root && -l "$root$rname" #- handle non-relative symlink which can be broken when non-rooted
            : whereis_binary($rname, $root))) {
        Sys::Syslog::syslog('warning', "program not found: $real_name");

        return;
    }

    if (my $pid = fork()) {
        if ($options->{detach}) {
            $pid;
        } else {
            my $ok;
            add2hash_($options, { timeout => $default_timeout });
            eval {
                local $SIG{ALRM} = sub { die "ALARM" };
                my $remaining = $options->{timeout} && $options->{timeout} ne 'never' &&  alarm($options->{timeout});
                waitpid $pid, 0;
                $ok = $? == -1 || ($? >> 8) == 0;
                alarm $remaining;
            };
            if ($@) {
                Sys::Syslog::syslog('warning', "ERROR: killing runaway process (process=$real_name, pid=$pid, args=@args, error=$@)");
                kill 9, $pid;
                return;
            }

            if ($stdout_raw && ref($stdout_raw)) {
                if (ref($stdout_raw) eq 'ARRAY') {
                    @$stdout_raw = cat_($stdout);
                } else {
                    $$stdout_raw = cat_($stdout);
                }
                unlink $stdout;
            }
            if ($stderr_raw && ref($stderr_raw)) {
                if (ref($stderr_raw) eq 'ARRAY') {
                    @$stderr_raw = cat_($stderr);
                } else {
                    $$stderr_raw = cat_($stderr);
                }
                unlink $stderr;
            }
            $ok;
        }
    } else {
        if ($options->{setuid}) {
            require POSIX;
            my ($logname, $home) = (getpwuid($options->{setuid}))[0,7];
            $ENV{LOGNAME} = $logname if $logname;

            # if we were root and are going to drop privilege, keep a copy of the X11 cookie:
            if (!$> && $home) {
                # FIXME: it would be better to remove this but most callers are using 'detach => 1'...
                my $xauth = chomp_(`mktemp $home/.Xauthority.XXXXX`);
                system('cp', '-a', $ENV{XAUTHORITY}, $xauth);
                system('chown', $logname, $xauth);
                $ENV{XAUTHORITY} = $xauth;
            }

            # drop privileges:
            POSIX::setuid($options->{setuid});
        }

        sub _die_exit {
            Sys::Syslog::syslog('warning', $_[0]);
            POSIX::_exit(128);
        }
        if ($stderr && $stderr eq 'STDERR') {
        } elsif ($stderr) {
            $stderr_mode =~ s/2//;
            open STDERR, "$stderr_mode $stderr" or _die_exit("ManaTools::Shared::RunProgram cannot output in $stderr (mode `$stderr_mode')");
        } elsif ($::isInstall) {
            open STDERR, ">> /tmp/ddebug.log" or open STDOUT, ">> /dev/tty7" or _die_exit("ManaTools::Shared::RunProgram cannot log, give me access to /tmp/ddebug.log");
        }
        if ($stdout && $stdout eq 'STDOUT') {
        } elsif ($stdout) {
            open STDOUT, "$stdout_mode $stdout" or _die_exit("ManaTools::Shared::RunProgram cannot output in $stdout (mode `$stdout_mode')");
        } elsif ($::isInstall) {
            open STDOUT, ">> /tmp/ddebug.log" or open STDOUT, ">> /dev/tty7" or _die_exit("ManaTools::Shared::RunProgram cannot log, give me access to /tmp/ddebug.log");
        }

        $root and chroot $root;
        chdir($options->{chdir} || "/");

        my $ok = ref $name ? do {
            exec { $name->[0] } $name->[1], @args;
        } : do {
            exec $name, @args;
        };
        my $exitcode = $!;
        return $exitcode if $options->{exitcode};
        if (!$ok) {
            _die_exit("exec of $real_name failed: $exitcode");
        }
    }

}

=item get_parent_uid()

Returns UID of the parent process.

=cut

sub _get_parent_uid() {
    cat_('/proc/' . getppid() . '/status') =~ /Uid:\s*(\d+)/ ? $1 : undef;
}



#- Local Variables:
#- mode:cperl
#- tab-width:8
#- End:
