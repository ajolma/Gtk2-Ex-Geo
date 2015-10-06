=pod

=head1 NAME

Gtk2::Ex::Geo::StyleElement::Size - A class for value(s) -> size converter

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $palette = Gtk2::Ex::Geo::StyleElement::Size->new( );

=head1 DESCRIPTION

Gtk2::Ex::Geo::Size is a tree of classes, which can convert a
property value (or property values) into a size.

=cut

package Gtk2::Ex::Geo::StyleElement::Size;

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

sub size {
}

sub size_range {
}

package Gtk2::Ex::Geo::StyleElement::Size::Simple;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Size );

sub order {
    return 1;
}

sub readable_class_name {
    return 'Fixed size';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{size} = 'Square';
    $self->{size} = $params{size} if exists $params{size};
    $self->{property_name} = undef;
    $self->{property_type} = undef;
}

sub size {
    my $self = shift;
    $self->{size} = shift if @_;
    return $self->{size};
}

package Gtk2::Ex::Geo::StyleElement::Size::Linear;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Size Gtk2::Ex::Geo::StyleElement::Linear );

sub order {
    return 3;
}

sub readable_class_name {
    return 'Linear size';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{min_value} = undef;
    $self->{min_value} = $params{min_value} if exists $params{min_value};
    $self->{max_value} = undef;
    $self->{max_value} = $params{max_value} if exists $params{max_value};
}

sub valid_property_type {
    my ($self, $type) = @_;
    return unless $type;
    return $type eq 'Integer' || $type eq 'Real';
}

sub value_range {
    my $self = shift;
    ($self->{min_value}, $self->{max_value}) = @_ if @_;
    return ($self->{min_value}, $self->{max_value});
}

sub size_range {
    my $self = shift;
    ($self->{min_size} = shift, $self->{max_size} = shift) if @_;
    return ($self->{min_size}, $self->{max_size});
}

sub size {
    my ($self, $value) = @_;
    return int($self->{min_size} + 
               ($value-$self->{min_value})/($self->{max_value}-$self->{min_value})*($self->{max_size}-$self->{min_size}));
}
*style = *size;

package Gtk2::Ex::Geo::StyleElement::Size::Lookup;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Size Gtk2::Ex::Geo::StyleElement::Lookup );

sub order {
    return 4;
}

sub readable_class_name {
    return 'Lookup table';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{size_table} = {};
    $self->{size_table} = Clone::clone($params{size_table}) if exists $params{size_table};
}

sub valid_property_type {
    my ($self, $type) = @_;
    return unless $type;
    return $type eq 'Integer' || $type eq 'String';
}

sub size {
    my ($self, $key, $size) = @_;
    $self->{table}->{$key} = $size if defined $size;
    return $self->{table}->{$key} if exists $self->{table}->{$key};
}

package Gtk2::Ex::Geo::StyleElement::Size::Bins;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::StyleElement::Size Gtk2::Ex::Geo::StyleElement::Bins );

sub order {
    return 5;
}

sub readable_class_name {
    return 'Bins';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{size_table} = [];
    $self->{size_table} = Clone::clone($params{size_table}) if exists $params{size_table};
}

sub valid_property_type {
    my ($self, $type) = @_;
    return unless $type;
    return $type eq 'Integer' || $type eq 'Real';
}

sub size {
    my ($self, $value, $size) = @_;
    $value = $self->{property_type} eq 'Integer' ? int($value) : $value;
    my $index = $self->index($value);
    $self->{table}->[$index] = [$value, $size] if defined $size;
    return $self->{table}->[$index]->[1];
}

1;
