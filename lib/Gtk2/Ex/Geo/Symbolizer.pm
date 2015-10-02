=pod

=head1 NAME

Gtk2::Ex::Geo::Symbolizer - A class for value(s) -> symbol converter

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $palette = Gtk2::Ex::Geo::Symbolizer->new( );

=head1 DESCRIPTION

Gtk2::Ex::Geo::Symbolizer is a tree of classes, which can convert a
property value (or property values) into a symbol. The simplest
symbolizer is a single symbol, while a complex symbolizer may use
several property values to compute a symbol.

In the GUI framework Gtk2::Ex::Geo::Symbolizer can be used as a model
for a Gtk2::Ex::Geo::Dialogs::Symbolizing view/controller (dialog).

=cut

package Gtk2::Ex::Geo::Symbolizer;

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

use vars qw//;

sub order {
}

sub readable_class_name {
}

sub new {
    my $class = shift;
    my %params = @_;
    my $self = $params{self} ? $params{self} : {};
    if ($params{readable_class_name}) {
        $class = undef;
        my $subclass_names = Class::Inspector->subclasses( 'Gtk2::Ex::Geo::Symbolizer' );
        for my $subclass (@$subclass_names) {
            my $name = eval $subclass.'->readable_class_name';
            if ($name && $name eq $params{readable_class_name}) {
                $class = $subclass;
                last;
            }
        }
        croak "Unknown symbolizer class: $params{readable_class_name}." unless $class;
    }
    bless $self => (ref($class) or $class);
    $self->initialize(@_);
    return $self;
}

sub initialize {
    my $self = shift;
    my %params = @_;
    $self->{property_name} = undef;# unless $self->{property_name};
    $self->{property_name} = $params{property_name};
    $self->{property_type} = undef;# unless $self->{property_type};
    $self->{property_type} = $params{property_type};
    $self->{style} = undef;# unless $self->{style};
    $self->{style} = $params{style};
}

sub shape {
}

sub size {
}

sub value_range {
}

sub property_value_at {
}

package Gtk2::Ex::Geo::Symbolizer::Simple;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::Symbolizer );

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
    $self->{shape} = 'Square';
    $self->{shape} = $params{shape} if $params{shape};
    $self->{size} = 5;
    $self->{size} = $params{size} if $params{size};
    $self->{property_name} = undef;
    $self->{property_type} = undef;
}

sub shape {
    my $self = shift;
    $self->{shape} = shift if @_;
    return $self->{shape};
}

sub size {
    my $self = shift;
    $self->{shape} = shift if @_;
    return $self->{shape};
}

#         symbol_size => 5, # symbol size is also the max size of the symbol, if symbol_scale is used
#        symbol_property_value_range => [0, 0],
#        symbol_size_range => [0, 0],
#        symbol_table => [],
#        symbol_bins => [],
# %SYMBOLS = ( 'Flow direction' => 1, 
#             Square => 2, 
#             Dot => 3, 
#             Cross => 4, 
#             'Wind rose' => 6,
#    );



1;
