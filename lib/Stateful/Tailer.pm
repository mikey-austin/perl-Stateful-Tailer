package Stateful::Tailer;

use 5.006;
use strict;
use warnings;

use YAML qw/DumpFile LoadFile/;
use Stateful::Tailer::Exception;
use Stateful::Tailer::File;

=head1 NAME

Stateful::Tailer - Tail multiple files and keep state between invocations.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Tail multiple files and keep state between invocations. Calls to read will not block, so it may be integrated into other event loops.

For example, it may be used in conjunction with Linux::Inotify2, where inotify triggers the reading based on the tailed files' events (eg IN_MODIFY OR IN_ATTRIB events).

    use Stateful::Tailer;

    my $tailer = Stateful::Tailer->new(
        files            => [ '/path/to/file1' ],
        include_patterns => [ 'greyd\[\d+\]:' ],
        except_patterns  => [ '^greylogd.*' ],
        state_file       => "/tmp/tailer.state",
        read_callback    => (
            sub {
                my $lines = shift; # Array ref.
                ...
            }
        ),
    );

    $tailer->read; # Does not block.

This module is completely object-oriented, with minimal dependencies (eg only YAML at this stage).

=head1 SUBROUTINES/METHODS

=head2 new

Constructor for the Stateful::Tailer class. On construction, the state file is automatically loaded or created if it does not exist.

=head3 parameters

=over 4

=item files (I<required>)

An ARRAY ref of file paths to tail.

=item state_file (I<required>)

The path to the state file in which the state of each tailed file is recorded in YAML. If the specified file does not exist, it will be created automatically.

=item include_patterns

An ARRAY ref of regular expressions to which all returned lines must match. If this parameter is specified, any lines that do not match an expression in the list will be silently ignored. Defaults to an empty ARRAY ref.

=item exclude_patterns

An ARRAY ref of regular expressions. Any line matching an expression in this list will be ignored, including those lines that match expressions in B<include_patterns> (if specified). Defaults to an empty ARRAY ref.

=item read_callback

The callback to be invoked (once per file) on read with the filtered lines. This callback is invoked with an ARRAY ref as a single argument. The callback will not be invoked if there are no lines.

=item debug

Print diagnostic messages to STDERR.

=back

=cut

sub new {
    my ($class, %args) = @_;

    die Stateful::Tailer::Exception->new('state_file required')
        if not defined $args{state_file};

    my $self = {
        _files      => {},
        _state      => undef,
        _state_path => $args{state_file},
        _include    => $args{include_patterns} || [],
        _exclude    => $args{exclude_patterns} || [],
        _read_cb    => $args{read_callback} || undef,
        _debug      => $args{debug} || 0,
    };
    bless $self, $class;

    $self->_load_files($args{files});
    $self->_load_state;

    return $self;
}

=head2 read

Read all lines from the specified files starting from the last saved position. If the state file does not exist, start reading from the beginning. The state is then saved after all files are read.

The specified files are processed in sequence. Calls to this subroutine will not block.

=cut

sub read {
    my $self = shift;
    my @lines;

    # Process files one at a time.
    foreach my $file (values %{$self->{_files}}) {
        eval {
            LINE: foreach my $line (@{$file->read_lines}) {
                # Process any exclusions first.
                foreach(@{$self->{_exclude}}) {
                    next LINE if $line =~ /$_/;
                }

                if(@{$self->{_include}} > 0) {
                    # Only include lines matching one of the patterns.
                    foreach(@{$self->{_include}}) {
                        if($line =~ /$_/) {
                            push @lines, $line;
                            next LINE;
                        }
                    }

                    # No explicit match, so silently ignore line.
                }
                else {
                    push @lines, $line;
                }
            }
        };

        if($@) {
            $self->_debug($@);
            $file->close_file;
        }
    }
    $self->_save_state;

    # Invoke callback with the filtered lines.
    $self->{_read_cb}->(\@lines)
        if @lines > 0 and defined $self->{_read_cb};
}

=head2 close_files

Close all configured files. This is called automatically on destruction.

=cut

sub close_files {
    foreach(values %{shift->{_files}}) {
        $_->close_file if defined $_;
    }
}

#
# Private functions.
#

sub _load_files {
    my ($self, $file_paths) = @_;
    $self->{_files}->{$_} = Stateful::Tailer::File->new($_, $self->{_debug})
        for @{$file_paths};
}

sub _debug {
    my ($self, $msg) = @_;
    print STDERR "DEBUG: $msg\n" if $self->{_debug};
}

sub _load_state {
    my $self = shift;

    if(-f $self->{_state_path}) {
        eval {
            $self->{_state} = LoadFile($self->{_state_path});
        };

        if($@) {
            die Stateful::Tailer::Exception->new(
                "could not load state from $self->{_state_path}: $@");
        }

        $_->load_from_state($self->{_state}) for values %{$self->{_files}};
    }
    else {
        #
        # Validate whether we are able to write to the state file,
        # creating it if it doesn't exist.
        #
        open(my $state_fh, '>>', $self->{_state_path})
            or die Stateful::Tailer::Exception->new('could not open state file: $!');
        close($state_fh);
    }
}

sub _save_state {
    my $self = shift;

    my $to_save = {};
    foreach my $file_path (keys %{$self->{_files}}) {
        $to_save->{$file_path} = $self->{_files}->{$file_path}->get_state;
    }

    eval {
        DumpFile($self->{_state_path}, $to_save);
    };

    if($@) {
        die Stateful::Tailer::Exception->new(
            "could not save state to $self->{_state_path}");
    }
}

sub DESTROY {
    shift->close_files;
}

=head1 AUTHOR

Mikey Austin, C<< <mikey at jackiemclean.net> >>


=head1 BUGS

Please report any bugs or feature requests to the author's email address.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Stateful::Tailer


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
