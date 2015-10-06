=pod

=head1 NAME

Gtk2::Ex::Geo::Labeler - A class for defining the labeling of a feature

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $labeling = Gtk2::Ex::Geo::Labeler->new( );

=head1 DESCRIPTION

Gtk2::Ex::Geo::Labeler is used as a part of a feature style.

In the GUI framework Gtk2::Ex::Geo::Labeler can be used as a model for
a Gtk2::Ex::Geo::Dialogs::Labeling view/controller (dialog).

=cut

package Gtk2::Ex::Geo::StyleElement::Labeler;

use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Class::Inspector;
use Clone;
use Gtk2::Ex::Geo::StyleElement;
use Glib qw/TRUE FALSE/;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement );

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{font_name} = 'Sans';
    $self->{font_name} = $params{font_name} if exists $params{font_name};
    $self->{font_size} = 12;
    $self->{font_size} = $params{font_size} if exists $params{font_size};
    $self->{font_color} = Gtk2::Ex::Geo::StyleElement::Color::SingleColor->new( symbolizer => $self->{symbolizer} );
    $self->{font_color} = $params{font_color} if exists $params{font_color};
    $self->{property_name} = undef;
    $self->{property_type} = undef;
}

sub font_properties {
    my ($self, $properties) = @_;
    if ($properties) {
        $self->{font_name} = $properties->{name} if exists $properties->{name};
        $self->{font_size} = $properties->{size} if exists $properties->{size};
        $self->{font_color} = $properties->{color} if exists $properties->{color};
    }
    $properties->{name} = $self->{font_name};
    $properties->{size} = $self->{font_size};
    $properties->{color} = $self->{font_color};
    return $properties;
}

sub placement {
}

sub placements {
}

package Gtk2::Ex::Geo::Labeler::ForPoints;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::Labeler );

sub order {
    return 1;
}

sub readable_class_name {
    return 'Simple';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{vert_nudge} = 0;
    $self->{vert_nudge} = $params{vert_nudge} if exists $params{vert_nudge};
    $self->{horiz_nudge} = 0;
    $self->{horiz_nudge} = $params{horiz_nudge} if exists $params{horiz_nudge};
    # min_size
    # incremental
}

sub placements {
    return ( 'Center', 'Center left', 'Center right', 
             'Top left', 'Top center', 'Top right', 
             'Bottom left', 'Bottom center', 'Bottom right' );
}
