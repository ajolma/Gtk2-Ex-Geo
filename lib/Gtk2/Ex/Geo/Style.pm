=pod

=head1 NAME

Gtk2::Ex::Geo::Style - A class for style information for geometric properties of geospatial features

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $style = Gtk2::Ex::Geo::Style->new( color => [0, 0, 0, 255] );

    $layer->assign_style($style, 'a_field');

=head1 DESCRIPTION

Gtk2::Ex::Geo::Style is information which is meant to be used when
features or elements of features are rendered.

Styling is a very large
topic. L<http://www.opengeospatial.org/standards/sld> defines an
approach. This module does not claim to cover the whole topic but be a
simple and extendable basis.

Style should be definable in text and interactively, using
dialogs. The Gtk2::Ex::Geo toolkit contains dialogs for defining basic
styles.

A style is always associated with only one geometric property (but one
geometry may have more than one style). The geometric property may be
a point, a curve, or a surface. Basic styling is using a (possibly
colored and varying size) symbol for a point, a line type (dash,
width, color) for a curve, and fill color for a surface. To render the
border line of a surface an additional style is needed. 

A style property (color, one of its elements, symbol size, symbol
type, dash type, line width) can be either static or linked to some
value (for example scalar valued field of the feature).

=cut

package Gtk2::Ex::Geo::Style;

use strict;
use warnings;
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Glib qw /TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs;
use Gtk2::Ex::Geo::Dialogs::Rules;
use Gtk2::Ex::Geo::Dialogs::Symbolizing;
use Gtk2::Ex::Geo::Dialogs::Coloring;
use Gtk2::Ex::Geo::Dialogs::Labeling;

use vars qw/%SYMBOLS %LABEL_PLACEMENTS/;

BEGIN {
     use Exporter 'import';
    our %EXPORT_TAGS = ( 'all' => [ qw(%SYMBOLS %LABEL_PLACEMENTS) ] );
    our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
}

%SYMBOLS = ( 'Flow direction' => 1, 
             Square => 2, 
             Dot => 3, 
             Cross => 4, 
             'Wind rose' => 6,
    );

%LABEL_PLACEMENTS = ( 'Center' => 0, 
                      'Center left' => 1, 
                      'Center right' => 2, 
                      'Top left' => 3, 
                      'Top center' => 4, 
                      'Top right' => 5, 
                      'Bottom left' => 6, 
                      'Bottom center' => 7, 
                      'Bottom right' => 8,
    );

sub new {
    my $class = shift;
    my %params = @_;
    my $self = $params{self} ? $params{self} : {};
    bless $self => (ref($class) or $class);
    $self->initialize(@_);
    return $self;
}

sub defaults {
    my $self = shift;
    return  {
        # coloring
        palette => Gtk2::Ex::Geo::ColorPalette->new( style => $self ),

        include_border => 0,
        border_color => [],
        
        # symbolization (only Style::Point)
        symbol_property => undef,
        symbol => undef,
        symbol_size => 5, # symbol size is also the max size of the symbol, if symbol_scale is used
        symbol_property_value_range => [0, 0],
        symbol_size_range => [0, 0],
        symbol_table => [],
        symbol_bins => [],
        
        # labeling
        label_property => undef,
        label_placement => 'Center',
        label_font => 'Sans 12',
        label_color => [0, 0, 0, 255],
        label_min_size => 0,
        incremental_labels => 0,
        label_vert_nudge => 0.3,
        label_horiz_nudge_left => 6,
        label_horiz_nudge_right => 10
    };
}

sub initialize {
    my $self = shift;
    my %params = @_;

    $self->{layer} = $params{layer};
    $self->{property} = $params{property};

    croak "Style initializer missing layer or property." unless $self->{layer} && $self->{property};

    # set defaults for all, order of preference is: 
    # user given as constructor parameter
    # subclass default
    # default as defined here

    my $defaults = $self->defaults;
    for my $property (keys %$defaults) {
        unless (ref $defaults->{$property}) {
            $self->{$property} = $defaults->{$property} unless exists $self->{$property};
            $self->{$property} = $params{$property} if exists $params{$property};
        } elsif (ref $defaults->{$property} eq 'ARRAY') {
            @{$self->{$property}} = @{$defaults->{$property}} unless exists $self->{$property};
            @{$self->{$property}} = @{$params{$property}} if exists $params{$property};
        } else { # currently this can only be an object
            $self->{$property} = $defaults->{$property} unless exists $self->{$property};
            $self->{$property} = $params{$property} if exists $params{$property};
        }
    }
    
}

sub clone {
    my ($self) = @_;
    my %params;
    my $defaults = $self->defaults;
    for my $property (keys %$defaults) {
        $params{$property} = $self->{$property};
    }
    my $clone = $self->new(%params);
}

sub restore_from {
    my ($self, $another_style) = @_;
    my $defaults = $self->defaults;
    for my $property (keys %$defaults) {
        $self->{$property} = $another_style->{$property};
    }
}

sub color_property {
    my($self, $property_name) = @_;
    if (defined $property_name) {
        my $s = $self->{layer}->schema;
        if ($s->{Properties}->{$property_name}) {
            $self->{color_property} = $property_name;
        } else {
            croak "Layer ", $self->{layer}->name, " does not have property called: '$property_name'.";
        }
    }
    return $self->{color_property};
}

=pod

=head2 palette_type()

Get or set the palette type for this layer.

=cut

sub palette {
    my($self, $palette) = @_;
    $self->{palette} = $palette if defined $palette;
    return $self->{palette};
}

sub color_table {
    my($self, $color_table) = @_;
    unless (defined $color_table) 
    {
        $self->{color_table} = [] unless $self->{color_table};
        return $self->{color_table};
    }
    if (ref($color_table) eq 'ARRAY') 
    {
        $self->{color_table} = [];
        for (@$color_table) {
            push @{$self->{color_table}}, [@$_];
        }
    } elsif (ref($color_table)) 
    {
        $self->{color_table} = [];
        for my $i (0..$color_table->GetCount-1) {
            my @color = $color_table->GetColorEntryAsRGB($i);
            push @{$self->{color_table}}, [$i, @color];
        }
    } else 
    {
        open(my $fh, '<', $color_table) or croak "can't read from $color_table: $!";
        $self->{color_table} = [];
        while (<$fh>) {
            next if /^#/;
            my @tokens = split /\s+/;
            next unless @tokens > 3;
            $tokens[4] = 255 unless defined $tokens[4];
            #print STDERR "@tokens\n";
            for (@tokens[1..4]) {
                $_ =~ s/\D//g;
            }
            #print STDERR "@tokens\n";
            for (@tokens[1..4]) {
                $_ = 0 if $_ < 0;
                $_ = 255 if $_ > 255;
            }
            #print STDERR "@tokens\n";
            push @{$self->{color_table}}, \@tokens;
        }
        CORE::close($fh);
    }
}

sub save_color_table {
    my($self, $filename) = @_;
    open(my $fh, '>', $filename) or croak "can't write to $filename: $!";
    for my $color (@{$self->{color_table}}) {
        print $fh "@$color\n";
    }
    CORE::close($fh);
}

sub color_bins {
    my($self, $color_bins) = @_;
    unless (defined $color_bins) {
        $self->{color_bins} = [] unless $self->{color_bins};
        return $self->{color_bins};
    }
    if (ref($color_bins) eq 'ARRAY') {
        $self->{color_bins} = [];
        for (@$color_bins) {
            push @{$self->{color_bins}}, [@$_];
        }
    } else {
        open(my $fh, '<', $color_bins) or croak "can't read from $color_bins: $!";
        $self->{color_bins} = [];
        while (<$fh>) {
            next if /^#/;
            my @tokens = split /\s+/;
            next unless @tokens > 3;
            $tokens[4] = 255 unless defined $tokens[4];
            for (@tokens[1..4]) {
                $_ =~ s/\D//g;
                $_ = 0 if $_ < 0;
                $_ = 255 if $_ > 255;
            }
            push @{$self->{color_bins}}, \@tokens;
        }
        CORE::close($fh);
    }
}

sub save_color_bins {
    my($self, $filename) = @_;
    open(my $fh, '>', $filename) or croak "can't write to $filename: $!";
    for my $color (@{$self->{color_bins}}) {
        print $fh "@$color\n";
    }
    CORE::close($fh);
}

sub remove_color {
    my($self, $index) = @_;
    if ($self->{palette_type} eq 'Color table') {
        splice @{$self->{color_table}}, $index, 1;
    } else {
        splice @{$self->{color_bins}}, $index, 1;
    }
}

sub color_from_palette {
    my $self = shift;
    my $index = shift unless $self->{palette_type} eq 'Single color';
    my @color = @_;
    if (@color) {
        if ($self->{palette_type} eq 'Color table') {
            $self->{color_table}[$index] = \@color;
        } elsif ($self->{palette_type} eq 'Color bins') {
            $self->{color_bins}[$index] = \@color;
        } else {
            $self->{color} = \@color;
        }
    } else {
        if ($self->{palette_type} eq 'Color table') {
            @color = @{$self->{color_table}[$index]};
        } elsif ($self->{palette_type} eq 'Color bins') {
            @color = @{$self->{color_bins}[$index]};
        } else {
            @color = @{$self->{color}};
        }
    }
    return @color;
}

sub include_border {
    my $self = shift;
    $self->{include_border} = shift if @_;
    return $self->{include_border};
}

sub border_color {
    my $self = shift;
    $self->{border_color} = [@_] if @_;
    return @{$self->{border_color}};
}

=pod

=head2 symbols()

Package subroutine.

The list of symbol types that this class supports. The list is used
in the symbol dialog box.

=cut

sub symbols {
    return sort {$SYMBOLS{$a} <=> $SYMBOLS{$b}} keys %SYMBOLS;
}

=pod

=head2 label_placements()

Package subroutine.

The list of valid label placements that this class supports. The list is used
in the symbol dialog box.

=cut

sub label_placements {
    return sort {$LABEL_PLACEMENTS{$a} <=> $LABEL_PLACEMENTS{$b}} keys %LABEL_PLACEMENTS;
}

=pod

=head2 symbol_property($property)

Get or set the property that is used to compute the symbol for this layer.

=cut

sub symbol_property {
    my($self, $property_name) = @_;
    if (defined $property_name) {
        if (exists $self->schema->{Propertys}->{$property_name}) {
            $self->{symbol_property} = $property_name;
        } else {
            croak "Layer ".$self->name()." does not have property with name: $property_name";
        }
    }
    return $self->{symbol_property};
}

=pod

=head2 symbol()

Get or set the symbol.

=cut

sub symbol {
    my($self, $symbol) = @_;
    $self->{symbol} = $symbol if defined $symbol;
    return $self->{symbol};
}

=pod

=head2 symbol_size()

Get or set the (fixed) symbol size for this layer.

=cut

sub symbol_size {
    my($self, $size) = @_;
    $self->{symbol_size} = defined $size ? $size+0 : $self->{symbol_size};
}

sub symbol_property_value_range {
    my($self, $min, $max) = @_;
    $self->{symbol_property_value_range} = [$min+0, $max+0] if defined $max;
    return @{$self->{symbol_property_value_range}};
}

sub labeling {
    my($self, $labeling) = @_;
    if ($labeling) {
        $self->{label_property} = $labeling->{property};
        $self->{label_placement} = $labeling->{placement};
        $self->{label_font} = $labeling->{font};
        @{$self->{label_color}} =@{$labeling->{color}};
        $self->{label_min_size} = $labeling->{min_size};
        $self->{incremental_labels} = $labeling->{incremental};
    } else {
        $labeling = {};
        $labeling->{property} = $self->{label_property};
        $labeling->{placement} = $self->{label_placement};
        $labeling->{font} = $self->{label_font};
        @{$labeling->{color}} = @{$self->{label_color}};
        $labeling->{min_size} = $self->{label_min_size};
        $labeling->{incremental} = $self->{incremental_labels};
    }
    return $labeling;
}

1;
