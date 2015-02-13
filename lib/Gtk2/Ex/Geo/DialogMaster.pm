#** @file DialogMaster.pm
#*
package Gtk2::Ex::Geo::DialogMaster;

use strict;
use warnings;
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
    $self->{buffer} = $params{buffer};
    bless $self => (ref($class) or $class);
}

sub get_dialog {
    my($self, $dialog_name) = @_;
    my @buf = ('<glade-interface>');
    my $push = 0;
    for (@{$self->{buffer}}) {
        # assumes top level widgets have two spaces indent
    	$push = 1 if (/^  <widget/ and /$dialog_name/);
	push @buf, $_ if $push;
	$push = 0 if /^  <\/widget/;
    }
    push @buf, '</glade-interface>';
    my $gladexml = Gtk2::GladeXML->new_from_buffer("@buf");
    my $dialog = $gladexml->get_widget($dialog_name);
    return unless $dialog;
    return $gladexml;
}

1;
