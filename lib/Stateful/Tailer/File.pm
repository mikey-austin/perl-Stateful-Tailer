package Stateful::Tailer::File;

use 5.006;
use strict;
use warnings;
use filetest 'access';

use Stateful::Tailer::Exception;

=head1 NAME

Stateful::Tailer::File - Class representing an individually tailed file.

=head1 SYNOPSIS

Internal class representing an individual tailed file.

=head1 SUBROUTINES/METHODS

=cut

sub new {
    my ($class, $path, $debug) = @_;

    die Stateful::Tailer::Exception->new("$path is not readable")
        if not -r $path;

    my $self = {
        _path  => $path,
        _pos   => 0,
        _fh    => undef,
        _stat  => {},
        _debug => $debug || 0,
    };
    bless $self, $class;

    return $self;
}

sub load_from_state {
    my ($self, $state) = @_;

    foreach(qw/pos/) {
        $self->{"_$_"} = $state->{$self->{_path}}->{$_}
            if defined $state->{$self->{_path}}->{$_};
    }

    $self->{_stat}->{$_} = $state->{$self->{_path}}->{$_}->{stat}->{$_}
        for qw/ino size atime mtime ctime/;
}

sub get_state {
    my $self = shift;
    my $state = {};
    $state->{$_} = $self->{"_$_"}
        for qw/path pos/;

    $state->{stat}->{$_} = $self->{_stat}->{$_}
        for qw/ino size atime mtime ctime/;

    return $state;
}

sub close_file {
    my $self = shift;
    close($self->{_fh}) if defined $self->{_fh};
    $self->{_fh} = undef;
    $self->_debug("closing $self->{_path}");
}

sub read_lines {
    my $self = shift;

    $self->_check_handle;
    my @lines = readline($self->{_fh});
    die Stateful::Tailer::Exception->new(
        "could not readline from $self->{_path}: $!") if $!;

    # Update file state.
    $self->{_pos} = $self->{_fh}->tell;
    $self->_load_stat;

    return \@lines;
}

sub _check_handle {
    my $self = shift;

    $self->_open_file if not defined $self->{_fh};

    # Detect file rotations/truncations.
    my @stat = $self->_get_stat($self->{_path});
    if($self->{_stat}->{ino} and $stat[1] != $self->{_stat}->{ino}) {
        $self->_debug("$self->{_path} inode has changed");
        $self->_reload;
    }
    elsif($self->{_stat}->{size} and $stat[7] < $self->{_stat}->{size}) {
        $self->_debug("$self->{_path} is smaller than expected, possible truncation");
        $self->_reload;
    }
    elsif($stat[7] < $self->{_pos}) {
        $self->_debug("$self->{_path} saved position is greater than file size, possible truncation");
        $self->_reload;
    }
}

sub _reload {
    my $self = shift;

    $self->close_file;
    $self->{_pos} = 0; # Read from the start.
    $self->_open_file;
}

sub _open_file {
    my $self = shift;

    $self->{_fh} = IO::File->new($self->{_path}, '<')
        or die Stateful::Tailer::Exception->new(
            "could not stat $self->{_path}");

    $self->{_fh}->seek($self->{_pos}, 0);
    $self->_debug("opening $self->{_path}, seeking to $self->{_pos}");
}

sub _load_stat {
    my $self = shift;
    my $s = $self->{_stat};
    ($s->{ino}, $s->{size}, $s->{atime}, $s->{mtime}, $s->{ctime})
        = ($self->_get_stat)[1, 7, 8, 9, 10];
}

sub _get_stat  {
    my ($self, $path) = @_;
    $path ||= $self->{_path};

    my @stats = stat($path);
    die Stateful::Tailer::Exception->new("could not stat $path")
        if @stats == 0;

    return @stats;
}

sub _debug {
    my ($self, $msg) = @_;
    print STDERR "DEBUG: $msg\n" if $self->{_debug};
}

=head1 AUTHOR

Mikey Austin, C<< <mikey at jackiemclean.net> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Mikey Austin.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Stateful::Tailer
