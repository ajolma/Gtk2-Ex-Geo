=pod

=head1 NAME

Gtk2::Ex::Geo::DialogMaster - A dialog manager

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 DESCRIPTION


=head1 METHODS

=cut

package Gtk2::Ex::Geo::DialogMaster;

use strict;
use warnings;
use locale;
use Carp;

BEGIN {
    use Exporter 'import';
    our @EXPORT = qw();
    our @EXPORT_OK = qw();
    our %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}

#** @method new(%params)
# Constructor to be used by the subclasses.
#*
sub new {
    my($class, %params) = @_;
    my $self = {};
    $self->{glade_interface} = $params{glade_interface};
    bless $self => (ref($class) or $class);
}

=pod

=head2 get_dialog($dialog_class)

Return a new widget (dialog box) of the given class by creating it
from the XML stored in this object.

=cut

sub get_dialog {
    my($self, $dialog_name) = @_;
    my @buf = ('<glade-interface>');
    my $push = 0;
    for (@{$self->{glade_interface}}) {
        # assumes top level widgets have two spaces indent
    	$push = 1 if (/^  <widget/ and /$dialog_name/);
	push @buf, $_ if $push;
	$push = 0 if /^  <\/widget/;
    }
    push @buf, '</glade-interface>';
    my $glade = Gtk2::GladeXML->new_from_buffer("@buf");
    return unless $glade->get_widget($dialog_name);
    return { glade => $glade };
}

1;
