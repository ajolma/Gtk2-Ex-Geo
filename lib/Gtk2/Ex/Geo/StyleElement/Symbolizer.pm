=pod

=head1 NAME

Gtk2::Ex::Geo::StyleElement::Symbolizer - A class for value(s) -> symbol converter

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $palette = Gtk2::Ex::Geo::StyleElement::Symbolizer->new( );

=head1 DESCRIPTION

Gtk2::Ex::Geo::Symbolizer is a tree of classes, which can convert a
property value (or property values) into a symbol. The simplest
symbolizer is a single symbol, while a complex symbolizer may use
several property values to compute a symbol.

In the GUI framework Gtk2::Ex::Geo::Symbolizer can be used as a model
for a Gtk2::Ex::Geo::Dialogs::Symbolizing view/controller (dialog).

=cut

package Gtk2::Ex::Geo::StyleElement::Symbolizer;

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

sub shape {
}

sub shapes {
}

sub size {
}

sub size_range {
}

package Gtk2::Ex::Geo::StyleElement::Symbolizer::Simple;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Symbolizer );

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
    $self->{shape} = $params{shape} if exists $params{shape};
    $self->{size} = 5;
    $self->{size} = $params{size} if exists $params{size};
    $self->{property_name} = undef;
    $self->{property_type} = undef;
}

sub shape {
    my $self = shift;
    $self->{shape} = shift if @_;
    return $self->{shape};
}

sub shapes {
    return qw/Square Circle Cross/;
}

sub size {
    my $self = shift;
    $self->{size} = shift if @_;
    return $self->{size};
}

package Gtk2::Ex::Geo::StyleElement::Symbolizer::VaryingSize;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Symbolizer );

sub order {
    return 2;
}

sub readable_class_name {
    return 'Varying size';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{shape} = 'Square';
    $self->{shape} = $params{shape} if exists $params{shape};
    $self->{min_size} = 1;
    $self->{min_size} = $params{min_size} if exists $params{min_size};
    $self->{max_size} = 10;
    $self->{max_size} = $params{max_size} if exists $params{max_size};
}

sub shape {
    my $self = shift;
    $self->{shape} = shift if @_;
    return $self->{shape};
}

sub shapes {
    return qw/Square Circle Cross/;
}

sub size_range {
    my $self = shift;
    if (@_) {
        $self->{min_size} = shift;
        $self->{max_size} = shift;
    }
    return ($self->{min_size}, $self->{max_size});
}

package Gtk2::Ex::Geo::StyleElement::Symbolizer::VaryingShape;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Symbolizer );

sub order {
    return 3;
}

sub readable_class_name {
    return 'Varying shape';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{size} = 5;
    $self->{size} = $params{size} if exists $params{size};
}

sub size {
    my $self = shift;
    $self->{size} = shift if @_;
    return $self->{size};
}

package Gtk2::Ex::Geo::StyleElement::Symbolizer::VaryingShapeAndSize;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Symbolizer );

sub order {
    return 4;
}

sub readable_class_name {
    return 'Varying shape and size';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;

    $self->{min_size} = 1;
    $self->{min_size} = $params{min_size} if exists $params{min_size};
    $self->{max_size} = 10;
    $self->{max_size} = $params{max_size} if exists $params{max_size};
}

sub size_range {
    my $self = shift;
    if (@_) {
        $self->{min_size} = shift;
        $self->{max_size} = shift;
    }
    return ($self->{min_size}, $self->{max_size});
}

1;
