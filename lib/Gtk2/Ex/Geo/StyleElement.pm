package Gtk2::Ex::Geo::StyleElement;

use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Class::Inspector;
use Clone;

sub clone {
    my ($self, $from) = @_;
    if ($from) {
        for my $property (keys %$self) {
            delete $self->{$property};
        }
        my $style = $from->{style};
        delete $from->{style};
        my $clone = Clone::clone($from);
        bless $self => ref($clone);
        for my $property (keys %$clone) {
            $self->{$property} = $clone->{$property};
        }
        $self->{style} = $style;
    } else {
        my $style = $self->{style};
        delete $self->{style};
        my $clone = Clone::clone($self);
        $self->{style} = $style;
        $clone->{style} = $style;
        return $clone;
    }
}

sub property {
    my $self = shift;
    if (@_) {
        $self->{property_name} = shift;
        my $type = shift;
        if ($type and not $self->valid_property_type($type)) {
            $self->{property_name} = undef;
            $self->{property_type} = undef;
            croak "Invalid property type: '$type' for $self.";
        }
        $self->{property_type} = $type;
    }
    return wantarray ? ($self->{property_name}, $self->{property_type}) : $self->{property_name};
}

sub valid_property_type {
}

sub property_type_for_GTK {
    my $self = shift;
    my $type = $self->{property_type};
    return unless $type;
    return 'Int' if $type eq 'Integer';
    return 'Double' if $type eq 'Real';
    return 'String' if $type eq 'String';
}

1;
