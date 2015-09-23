=pod

=head1 NAME

Gtk2::Ex::Geo::Layer - A root class for geospatial layers

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $glue = Gtk2::Ex::Geo::Glue->new();

    $glue->register_class('Gtk2::Ex::Geo::Layer');

=head1 DESCRIPTION

Gtk2::Ex::Geo::Layer defines the interface and a reference
implementation of a layer class in the Gtk2::Ex::Geo toolkit. Layer
classes do not have to subclass from the Gtk2::Ex::Geo::Layer class as
long as they implement the layer interface but this class can be used
as a root class to exploit the dialogs it provides for defining color
palettes etc.

Layer classes should be registered with the $glue object to make
them available in the GUI.

Layer objects are added to the GUI using the add_layer method of Glue.

=cut

package Gtk2::Ex::Geo::Layer;

use strict;
use warnings;
use Scalar::Util qw(blessed);
use Carp;
use Glib qw /TRUE FALSE/;
use Gtk2::Ex::Geo::Dialogs;
use Gtk2::Ex::Geo::Dialogs::Rules;
use Gtk2::Ex::Geo::Dialogs::Symbols;
use Gtk2::Ex::Geo::Dialogs::Colors;
use Gtk2::Ex::Geo::Dialogs::Labeling;

use vars qw/%PALETTE_TYPE %GRAYSCALE_SUBTYPE %SYMBOL_TYPE %LABEL_PLACEMENT $SINGLE_COLOR/;

BEGIN {
    use Exporter 'import';
    our %EXPORT_TAGS = ( 'all' => [ qw(%PALETTE_TYPE %GRAYSCALE_SUBTYPE %SYMBOL_TYPE %LABEL_PLACEMENT) ] );
    our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
}

# default values for new objects

$SINGLE_COLOR = [0, 0, 0, 255];

# the integer values are the same as in libral visualization code:

%PALETTE_TYPE = ( 'Single color' => 0, 
                  Grayscale => 1, 
                  Rainbow => 2, 
                  'Color table' => 3, 
                  'Color bins' => 4,
                  'Red channel' => 5, 
                  'Green channel' => 6, 
                  'Blue channel' => 7,
    );

%GRAYSCALE_SUBTYPE = ( Gray => 0,
                       Hue => 1,
                       Saturation => 2,
                       Value => 3,
                       Opacity => 4,
    );

%SYMBOL_TYPE = ( 'No symbol' => 0, 
                 'Flow_direction' => 1, 
                 Square => 2, 
                 Dot => 3, 
                 Cross => 4, 
                 'Wind rose' => 6,
    );

%LABEL_PLACEMENT = ( 'Center' => 0, 
                     'Center left' => 1, 
                     'Center right' => 2, 
                     'Top left' => 3, 
                     'Top center' => 4, 
                     'Top right' => 5, 
                     'Bottom left' => 6, 
                     'Bottom center' => 7, 
                     'Bottom right' => 8,
    );

=pod

=head1 LAYER INTERFACE

These subroutines are invoked by the glue or overlay objects on layer
objects as methods or on the layer class as package subroutines.

Note: currently the glue object uses the key _tree_index and assumes
that the layer object is a hash reference.

=head2 registration($glue)

Package subroutine to obtain information about the layer class in an
anonymous hash.

$glue is the glue object (currently not used)

The returned hash should have the following keywords:

=over

=item dialogs

A dialog manager. Typically a subclass of Gtk2::Ex::Geo::DialogMaster.

=item commands

A reference to a list, which defines a button and its associated
action to the toolbar in the GUI for this class. Typically this is a
menu, which opens when the button is pressed.

A menu is defined by a list, which begins with a set of key - value
pairs defining the button followed by a set of hash references
defining the menu items. Keywords for defining the button include
stock_id, label, tip, pos (for the location of the button within the
toolbar). Keywords for defining the menu items include label and sub.

To do: explain adding non-menu commands.

=back

=cut

sub registration {
    my($glue) = @_;
    if ($glue->{resources}{icons}{dir}) {
        #print STDERR "reg: @{$glue->{resources}{icons}{dir}}\n";
    }
    my $dialogs = Gtk2::Ex::Geo::Dialogs->new();
    return { dialogs => $dialogs };
}

=pod

=head2 menu_items()

Menu items for a context menu of this layer object as a list
reference.

A menu item consists of an entry and action. The action may be an
subroutine reference or FALSE, in which case a separator item is
added. A '_' in front of a letter makes that letter a shortcut key for
the item. The final layer menu is composed of entries added by the
glue object and all classes in the layers lineage. The subroutine is
called with [$self, $glue] as user data.

Tod: add machinery for multiselection.

=cut

sub menu_items {
    my($self) = @_;
    my @items;
    push @items, (
        '_Unselect all' => sub {
            my($self, $gui) = @{$_[1]};
            $self->select;
            $gui->{overlay}->update_image;
            $self->open_features_dialog($gui, 1);
        },
        '_Rules...' => sub {
             my($self, $gui) = @{$_[1]};
             $self->open_rules_dialog($gui);
        },
        '_Symbol...' => sub {
             my($self, $gui) = @{$_[1]};
             $self->open_symbols_dialog($gui);
        },
        '_Colors...' => sub {
             my($self, $gui) = @{$_[1]};
             $self->open_colors_dialog($gui);
        },
        '_Labeling...' => sub {
            my($self, $gui) = @{$_[1]};
            $self->open_labeling_dialog($gui);
        },
        '_Inspect...' => sub {
            my($self, $gui) = @{$_[1]};
            $gui->inspect($self->inspect_data, $self->name);
        },
        '_Properties...' => sub {
            my($self, $gui) = @{$_[1]};
            $self->open_properties_dialog($gui);
        }
    );
    return @items;
}

=pod

=head2 upgrade($object)

Package subroutine.

Create a layer object from a data object.

Return a layer object if upgrade was possible (or the object already
belongs to this class). Otherwise return false.

Optional, used only if exists.

=head2 close($glue)

Close and destroy all resources of this layer, as it has been removed
from the GUI.

If you override this, remember to call the super method:

    $self->SUPER::close(@_);

Required by the glue object.

=cut

sub close {
    my($self, $gui) = @_;
    for (keys %$self) {
        if (blessed($self->{$_}) and $self->{$_}->isa("Gtk2::GladeXML")) {
            $self->{$_}->get_widget($_)->destroy;
        }
        delete $self->{$_};
    }
}

=pod

=head2 type($format)

Return the type of this layer for the GUI (a short but human readable
code, typically one or two characters). If $format is 'long' you may
return a longer description.

Required by the glue object.

=cut

sub type {
    my $self = shift;
    return '?';
}

=pod

=head2 name($name)

Get or set the name of the layer object.

Required by the glue and overlay objects.

=cut

sub name {
    my($self, $name) = @_;
    defined $name ? $self->{NAME} = $name : $self->{NAME};
}

=pod

=head2 world()

The bounding box (a list min x, min y, max x, max y) of the layer object.

Required by the overlay object.

=cut

=pod

=head2 alpha($alpha)

Get or set the alpha (transparency) of the layer. Alpha is an integer
value between 0 and 255.

Required by the glue object.

=cut

sub alpha {
    my($self, $alpha) = @_;
    if (defined $alpha) {
        $alpha = 0 if $alpha < 0;
        $alpha = 255 if $alpha > 255;
        $self->{ALPHA} = $alpha;
    }
    $self->{ALPHA};
}

=pod

=head2 visible($visibility)

Get or set the visibility state of this layer.

Required by the overlay object.

=cut

sub visible {
    my $self = shift;
    $self->{VISIBLE} = shift if @_;
    return $self->{VISIBLE};
}

=pod

=head2 got_focus($glue)

A callback, which is invoked when this layer gets the cursor in the
layer list.

Required by the glue object.

=cut

sub got_focus {
    my($self, $gui) = @_;
}

=pod

=head2 lost_focus($glue)

A callback, which is invoked when the cursor is moved away from this
layer in the layer list.

Required by the glue object.

=cut

sub lost_focus {
    my($self, $gui) = @_;
}

=pod

=head2 select($selecting => $selection)

Invoked for the selected layer after the user has made a new selection.

$selecting ($glue->{selecting}) is either 'that_are_within',
'that_contain' or 'that_intersect'.

$selection ($overlay->{selection}) is a Geo::OGC::Geometry object.

If called without parameters, deselect all features.

If the layer has GUI widgets which show selected features, it should
update those.

=cut

sub select {
    my($self, %params) = @_;
    if (@_ > 1) {
        for my $key (keys %params) {
            my $features = $self->features($key => $params{$key});
            $self->selected_features($features);
        }
    } else {
        $self->{SELECTED_FEATURES} = [];
    }
    $self->open_features_dialog($self, $params{glue}, 1);
}

=pod

=head2 render_selection($gc, $overlay)

$gc is a Gtk2::Gdk::GC (graphics context) onto which to draw the
selection.

Todo: document.

=cut

sub render_selection {
}

=pod

=head2 render($pb, $cr, $overlay, $viewport)

A request to render the data of the layer onto a surface.

$pb is a (XS wrapped) pointer to a gtk2_ex_geo_pixbuf,

$cr is a Cairo::Context object for the surface to draw on,

$overlay is the Gtk2::Ex::Geo::Overlay object which manages the
surface, and

$viewport is a reference to the bounding box [min_x, min_y, max_x,
max_y] of the surface in world coordinates.

=cut

sub render {
    my($self, $pb, $cr, $overlay, $viewport) = @_;
}

=pod

=head2 statusbar_info($x, $y)

A request for an information string for the statusbar of the GUI.

$x, $y is the location of the mouse.

=cut

sub statusbar_info {
    my($self, $x, $y) = @_;
    return '';
}

=pod

=head1 REFERENCE IMPLEMENTATION

The goal of the reference implementation of a Gtk2::Ex::Geo::Layer is
to be useful as a root class for common geospatial layer classes. To
achieve this goal it contains generic symbolization (colors, symbols,
labels, etc) support.

=cut

sub new {
    my($class, %params) = @_;
    my $self = $params{self} ? $params{self} : {};
    bless $self => (ref($class) or $class);
    $self->defaults(%params);
    return $self;
}

sub defaults {
    my($self, %params) = @_;

    # set defaults for all

    $self->{NAME} = '' unless exists $self->{NAME};
    $self->{ALPHA} = 255 unless exists $self->{ALPHA};
    $self->{VISIBLE} = 1 unless exists $self->{VISIBLE};
    $self->{PALETTE_TYPE} = 'Single color' unless exists $self->{PALETTE_TYPE};

    $self->{SYMBOL_TYPE} = 'No symbol' unless exists $self->{SYMBOL_TYPE};
    # symbol size is also the max size of the symbol, if symbol_scale is used
    $self->{SYMBOL_SIZE} = 5 unless exists $self->{SYMBOL_SIZE}; 
    # symbol scale is similar to grayscale scale
    $self->{SYMBOL_SCALE_MIN} = 0 unless exists $self->{SYMBOL_SCALE_MIN}; 
    $self->{SYMBOL_SCALE_MAX} = 0 unless exists $self->{SYMBOL_SCALE_MAX};

    $self->{HUE_AT_MIN} = 235 unless exists $self->{HUE_AT_MIN}; # as in libral visual.h
    $self->{HUE_AT_MAX} = 0 unless exists $self->{HUE_AT_MAX}; # as in libral visual.h
    $self->{INVERT} = 0 unless exists $self->{HUE_DIR}; # inverted scale or not; RGB is not inverted
    $self->{GRAYSCALE_SUBTYPE} = 'Gray' unless exists $self->{GRAYSCALE_SUBTYPE}; # grayscale is gray scale

    @{$self->{GRAYSCALE_COLOR}} = @$SINGLE_COLOR unless exists $self->{GRAYSCALE_COLOR};

    @{$self->{SINGLE_COLOR}} = @$SINGLE_COLOR unless exists $self->{SINGLE_COLOR};

    $self->{COLOR_TABLE} = [] unless exists $self->{COLOR_TABLE};
    $self->{COLOR_BINS} = [] unless exists $self->{COLOR_BINS};

    # scales are used in rendering in some palette types
    $self->{COLOR_SCALE_MIN} = 0 unless exists $self->{COLOR_SCALE_MIN};
    $self->{COLOR_SCALE_MAX} = 0 unless exists $self->{COLOR_SCALE_MAX};

    # focus field is used in rendering and rasterization
    # this is the name of the field
    $self->{COLOR_FIELD} = '' unless exists $self->{COLOR_FIELD};
    $self->{SYMBOL_FIELD} = 'Fixed size' unless exists $self->{SYMBOL_FIELD};
    $self->{LABEL_FIELD} = 'No Labels'  unless exists $self->{LABEL_FIELD};

    $self->{LABEL_PLACEMENT} = 'Center' unless exists $self->{LABEL_PLACEMENT};
    $self->{LABEL_FONT} = 'sans 12' unless exists $self->{LABEL_FONT};
    $self->{LABEL_COLOR} = [0, 0, 0, 255] unless exists $self->{LABEL_COLOR};
    $self->{LABEL_MIN_SIZE} = 0 unless exists $self->{LABEL_MIN_SIZE};
    $self->{INCREMENTAL_LABELS} = 0 unless exists $self->{INCREMENTAL_LABELS};
    $self->{LABEL_VERT_NUDGE} = 0.3 unless exists $self->{LABEL_VERT_NUDGE};
    $self->{LABEL_HORIZ_NUDGE_LEFT} = 6 unless exists $self->{LABEL_HORIZ_NUDGE_LEFT};
    $self->{LABEL_HORIZ_NUDGE_RIGHT} = 10 unless exists $self->{LABEL_HORIZ_NUDGE_RIGHT};

    $self->{BORDER_COLOR} = [] unless exists $self->{BORDER_COLOR};

    $self->{SELECTED_FEATURES} = [];
    
    $self->{RENDERER} = 0; # the default, later 'Cairo' will be implemented fully
  
    # set from input
    
    $self->{NAME} = $params{name} if exists $params{name};
    $self->{ALPHA} = $params{alpha} if exists $params{alpha};
    $self->{VISIBLE} = $params{visible} if exists $params{visible};
    $self->{PALETTE_TYPE} = $params{palette_type} if exists $params{palette_type};
    $self->{SYMBOL_TYPE} = $params{symbol_type} if exists $params{symbol_type};
    $self->{SYMBOL_SIZE} = $params{symbol_size} if exists $params{symbol_size};
    $self->{SYMBOL_SCALE_MIN} = $params{scale_min} if exists $params{scale_min};
    $self->{SYMBOL_SCALE_MAX} = $params{scale_max} if exists $params{scale_max};
    $self->{HUE_AT_MIN} = $params{hue_at_min} if exists $params{hue_at_min};
    $self->{HUE_AT_MAX} = $params{hue_at_max} if exists $params{hue_at_max};
    $self->{INVERT} = $params{invert} if exists $params{invert};
    $self->{SCALE} = $params{scale} if exists $params{scale};
    @{$self->{GRAYSCALE_COLOR}} = @{$params{grayscale_color}} if exists $params{grayscale_color};
    @{$self->{SINGLE_COLOR}} = @{$params{single_color}} if exists $params{single_color};
    $self->{COLOR_TABLE} = $params{color_table} if exists $params{color_table};
    $self->{COLOR_BINS} = $params{color_bins} if exists $params{color_bins};
    $self->{COLOR_SCALE_MIN} = $params{color_scale_min} if exists $params{color_scale_min};
    $self->{COLOR_SCALE_MAX} = $params{color_scale_max} if exists $params{color_scale_max};
    $self->{COLOR_FIELD} = $params{color_field} if exists $params{color_field};
    $self->{SYMBOL_FIELD} = $params{symbol_field} if exists $params{symbol_field};
    $self->{LABEL_FIELD} = $params{label_field} if exists $params{label_field};
    $self->{LABEL_PLACEMENT} = $params{label_placement} if exists $params{label_placement};
    $self->{LABEL_FONT} = $params{label_font} if exists $params{label_font};
    @{$self->{LABEL_COLOR}} = @{$params{label_color}} if exists $params{label_color};
    $self->{LABEL_MIN_SIZE} = $params{label_min_size} if exists $params{label_min_size};
    @{$self->{BORDER_COLOR}} = @{$params{border_color}} if exists $params{border_color};

}

sub DESTROY {
    my $self = shift;
    while (my($key, $widget) = each %$self) {
        $widget->destroy if blessed($widget) and $widget->isa("Gtk2::Widget");
        delete $self->{$key};
    }
}

## @method @palette_types()
#
# @brief A class method. Returns a list of valid palette types (strings).
# @return a list of valid palette types (strings).
sub palette_types {
    return sort {$PALETTE_TYPE{$a} <=> $PALETTE_TYPE{$b}} keys %PALETTE_TYPE;
}

## @method @symbol_types()
#
# @brief A class method. Returns a list of valid symbol types (strings).
# @return a list of valid symbol types (strings).
sub symbol_types {
    return sort {$SYMBOL_TYPE{$a} <=> $SYMBOL_TYPE{$b}} keys %SYMBOL_TYPE;
}

## @method @label_placements()
#
# @brief Returns a list of valid label_placements (strings).
# @return a list of valid label_placements (strings).
sub label_placements {
    return sort {$LABEL_PLACEMENT{$a} <=> $LABEL_PLACEMENT{$b}} keys %LABEL_PLACEMENT;
}

sub inspect_data {
    my $self = shift;
    return $self;
}

sub palette_type {
    my($self, $palette_type) = @_;
    if (defined $palette_type) {
        croak "Unknown palette type: $palette_type" unless defined $PALETTE_TYPE{$palette_type};
        $self->{PALETTE_TYPE} = $palette_type;
    } else {
        return $self->{PALETTE_TYPE};
    }
}

sub supported_palette_types {
    my($class) = @_;
    my @ret;
    for my $t (sort {$PALETTE_TYPE{$a} <=> $PALETTE_TYPE{$b}} keys %PALETTE_TYPE) {
        push @ret, $t;
    }
    return @ret;
}

sub symbol_type {
    my($self, $symbol_type) = @_;
    if (defined $symbol_type) {
        croak "Unknown symbol type: $symbol_type" unless defined $SYMBOL_TYPE{$symbol_type};
        $self->{SYMBOL_TYPE} = $symbol_type;
    } else {
        return $self->{SYMBOL_TYPE};
    }
}

sub supported_symbol_types {
    my($self) = @_;
    my @ret;
    for my $t (sort {$SYMBOL_TYPE{$a} <=> $SYMBOL_TYPE{$b}} keys %SYMBOL_TYPE) {
        push @ret, $t;
    }
    return @ret;
}

sub symbol_size {
    my($self, $size) = @_;
    defined $size ?
        $self->{SYMBOL_SIZE} = $size+0 :
        $self->{SYMBOL_SIZE};
}

sub symbol_scale {
    my($self, $min, $max) = @_;
    if (defined $min) {
                $self->{SYMBOL_SCALE_MIN} = $min+0;
                $self->{SYMBOL_SCALE_MAX} = $max+0;
    }
    return ($self->{SYMBOL_SCALE_MIN}, $self->{SYMBOL_SCALE_MAX});
}

sub hue_range {
    my($self, $min, $max, $dir) = @_;
    if (defined $min) {
                $self->{HUE_AT_MIN} = $min+0;
                $self->{HUE_AT_MAX} = $max+0;
                $self->{INVERT} = (!(defined $dir) or $dir == 1) ? 0 : 1;
    }
    return ($self->{HUE_AT_MIN}, $self->{HUE_AT_MAX}, $self->{INVERT} ? -1 : 1);
}

sub grayscale_subtype {
    my($self, $scale) = @_;
    if (defined $scale) {
        croak "unknown grayscale subtype: $scale" unless exists $GRAYSCALE_SUBTYPE{$scale};
        $self->{GRAYSCALE_SUBTYPE} = $scale;
    } else {
        $self->{GRAYSCALE_SUBTYPE};
    }
}

sub invert_scale {
    my($self, $invert) = @_;
    if (defined $invert) {
        $self->{INVERT} = $invert and 1;
    } else {
        $self->{INVERT};
    }
}

sub grayscale_color {
    my $self = shift;
    croak "@_ is not a RGBA color" if @_ and @_ != 4;
    $self->{GRAYSCALE_COLOR} = [@_] if @_;
    return @{$self->{GRAYSCALE_COLOR}};
}

sub symbol_field {
    my($self, $field_name) = @_;
    if (defined $field_name) {
        if ($field_name eq 'Fixed size' or $self->schema->field($field_name)) {
            $self->{SYMBOL_FIELD} = $field_name;
        } else {
            croak "Layer ".$self->name()." does not have field with name: $field_name";
        }
    }
    return $self->{SYMBOL_FIELD};
}

sub single_color {
    my $self = shift;
    croak "@_ is not a RGBA color" if @_ and @_ != 4;
    $self->{SINGLE_COLOR} = [@_] if @_;
    return @{$self->{SINGLE_COLOR}};
}

sub color_scale {
    my($self, $min, $max) = @_;
    if (defined $min) {
        $min = 0 unless $min;
        $max = 0 unless $max;
        $self->{COLOR_SCALE_MIN} = $min;
        $self->{COLOR_SCALE_MAX} = $max;
    }
    return ($self->{COLOR_SCALE_MIN}, $self->{COLOR_SCALE_MAX});
}

sub color_field {
    my($self, $field_name) = @_;
    if (defined $field_name) {
        if ($self->schema->field($field_name)) {
            $self->{COLOR_FIELD} = $field_name;
        } else {
            croak "Layer ", $self->name, " does not have field: $field_name";
        }
    }
    return $self->{COLOR_FIELD};
}

sub color_table {
    my($self, $color_table) = @_;
    unless (defined $color_table) 
    {
        $self->{COLOR_TABLE} = [] unless $self->{COLOR_TABLE};
        return $self->{COLOR_TABLE};
    }
    if (ref($color_table) eq 'ARRAY') 
    {
        $self->{COLOR_TABLE} = [];
        for (@$color_table) {
            push @{$self->{COLOR_TABLE}}, [@$_];
        }
    } elsif (ref($color_table)) 
    {
        $self->{COLOR_TABLE} = [];
        for my $i (0..$color_table->GetCount-1) {
            my @color = $color_table->GetColorEntryAsRGB($i);
            push @{$self->{COLOR_TABLE}}, [$i, @color];
        }
    } else 
    {
        open(my $fh, '<', $color_table) or croak "can't read from $color_table: $!";
        $self->{COLOR_TABLE} = [];
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
            push @{$self->{COLOR_TABLE}}, \@tokens;
        }
        CORE::close($fh);
    }
}

sub color {
    my $self = shift;
    my $index = shift unless $self->{PALETTE_TYPE} eq 'Single color';
    my @color = @_ if @_;
    if (@color) {
        if ($self->{PALETTE_TYPE} eq 'Color table') {
            $self->{COLOR_TABLE}[$index] = \@color;
        } elsif ($self->{PALETTE_TYPE} eq 'Color bins') {
            $self->{COLOR_BINS}[$index] = \@color;
        } else {
            $self->{SINGLE_COLOR} = \@color;
        }
    } else {
        if ($self->{PALETTE_TYPE} eq 'Color table') {
            @color = @{$self->{COLOR_TABLE}[$index]};
        } elsif ($self->{PALETTE_TYPE} eq 'Color bins') {
            @color = @{$self->{COLOR_BINS}[$index]};
        } else {
            @color = @{$self->{SINGLE_COLOR}};
        }
    }
    return @color;
}

sub add_color {
    my($self, $index, @XRGBA) = @_;
    if ($self->{PALETTE_TYPE} eq 'Color table') {
        splice @{$self->{COLOR_TABLE}}, $index, 0, [@XRGBA];
    } else {
        splice @{$self->{COLOR_BINS}}, $index, 0, [@XRGBA];
    }
}

sub remove_color {
    my($self, $index) = @_;
    if ($self->{PALETTE_TYPE} eq 'Color table') {
        splice @{$self->{COLOR_TABLE}}, $index, 1;
    } else {
        splice @{$self->{COLOR_BINS}}, $index, 1;
    }
}


sub save_color_table {
    my($self, $filename) = @_;
    open(my $fh, '>', $filename) or croak "can't write to $filename: $!";
    for my $color (@{$self->{COLOR_TABLE}}) {
        print $fh "@$color\n";
    }
    CORE::close($fh);
}

sub color_bins {
    my($self, $color_bins) = @_;
    unless (defined $color_bins) {
        $self->{COLOR_BINS} = [] unless $self->{COLOR_BINS};
        return $self->{COLOR_BINS};
    }
    if (ref($color_bins) eq 'ARRAY') {
        $self->{COLOR_BINS} = [];
        for (@$color_bins) {
            push @{$self->{COLOR_BINS}}, [@$_];
        }
    } else {
        open(my $fh, '<', $color_bins) or croak "can't read from $color_bins: $!";
        $self->{COLOR_BINS} = [];
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
            push @{$self->{COLOR_BINS}}, \@tokens;
        }
        CORE::close($fh);
    }
}

sub save_color_bins {
    my($self, $filename) = @_;
    open(my $fh, '>', $filename) or croak "can't write to $filename: $!";
    for my $color (@{$self->{COLOR_BINS}}) {
        print $fh "@$color\n";
    }
    CORE::close($fh);
}

sub border_color {
    my($self, @color) = @_;
    @{$self->{BORDER_COLOR}} = @color if @color;
    return @{$self->{BORDER_COLOR}} if defined wantarray;
    @{$self->{BORDER_COLOR}} = () unless @color;
}

sub labeling {
    my($self, $labeling) = @_;
    if ($labeling) {
        $self->{LABEL_FIELD} = $labeling->{field};
        $self->{LABEL_PLACEMENT} = $labeling->{placement};
        $self->{LABEL_FONT} = $labeling->{font};
        @{$self->{LABEL_COLOR}} =@{$labeling->{color}};
        $self->{LABEL_MIN_SIZE} = $labeling->{min_size};
        $self->{INCREMENTAL_LABELS} = $labeling->{incremental};
    } else {
        $labeling = {};
        $labeling->{field} = $self->{LABEL_FIELD};
        $labeling->{placement} = $self->{LABEL_PLACEMENT};
        $labeling->{font} = $self->{LABEL_FONT};
        @{$labeling->{color}} = @{$self->{LABEL_COLOR}};
        $labeling->{min_size} = $self->{LABEL_MIN_SIZE};
        $labeling->{incremental} = $self->{INCREMENTAL_LABELS};
    }
    return $labeling;
}

sub selected_features {
    my($self, $selected) = @_;
    if (@_ > 1) {
        $self->{SELECTED_FEATURES} = $selected;
    }
    return $self->{SELECTED_FEATURES};
}

sub features {
}

sub has_features_with_borders {
    return 0;
}

sub schema {
    my $schema = Gtk2::Ex::Geo::Schema->new;
    return $schema;
}

sub value_range {
    return (0, 0);
}

=pod

=head1 DIALOGS

The Gtk2::Ex::Geo::Layer class uses five dialogs: colors, colors_from,
labels, symbols, and rules. These are stored and managed by the
Gtk2::Ex::Geo::Dialogs package.

=head2 open_properties_dialog($glue)

=cut


sub open_properties_dialog {
    my($self, $gui) = @_;
}

=pod

=head2 open_features_dialog($glue, $new_selection)

A request to invoke a features dialog for this layer object. If
$new_selection exists and is true, the dialog should only be refreshed
if it is open.

=cut

sub open_features_dialog {
    my($self, $gui, $soft_open) = @_;
}

=pod

=head2 open_rules_dialog($glue)

=cut

sub open_rules_dialog {
    Gtk2::Ex::Geo::Dialogs::Rules::open(@_);
}

=pod

=head2 open_symbols_dialog($glue)

=cut

sub open_symbols_dialog {
    Gtk2::Ex::Geo::Dialogs::Symbols::open(@_);
}

=pod

=head2 open_colors_dialog($glue)

=cut

sub open_colors_dialog {
    Gtk2::Ex::Geo::Dialogs::Colors::open(@_);
}

=pod

=head2 open_labeling_dialog($glue)

=cut

sub open_labeling_dialog {
    Gtk2::Ex::Geo::Dialogs::Labeling::open(@_);
}

=pod

=head2 bootstrap_dialog($glue, $dialog_class, $title, $connects, $combos)

Called by the "open" method of a dialog class to create and initialize
or restore a dialog object of a given class. If the dialog does not
exist, one is obtained from the glue object, which in turn obtains
it from the Dialogs object of this or some other layer class.

$title is the title for the dialog box.

$connects is a reference to a hash of widget names, which are
associated with a reference to a list of signal name, subroutine
reference, and user parameter. For example

    copy_button => [clicked => \&do_copy, [$layer, $glue]]

$combos is a reference to a list of name of simple ComboBoxes that
need a model and a text renderer in initialization.

The method returns the dialog box widget and a boolean value, which
indicates whether the dialog box was created or if it already existed.

Not part of the Layer interface. Used by the glue object for the
introspection dialog.

=cut

sub bootstrap_dialog {
    my($self, $gui, $dialog, $title, $connects, $combos) = @_;
    $self = {} unless $self;
    my $boot = 0;
    my $widget;
    unless ($self->{$dialog}) {
        $self->{$dialog} = $gui->get_dialog($dialog);
        croak "$dialog does not exist" unless $self->{$dialog};
        $widget = $self->{$dialog}->get_widget($dialog);
        if ($connects) {
            for my $n (keys %$connects) {
                my $w = $self->{$dialog}->get_widget($n);
                #print STDERR "connect: '$n'\n";
                $w->signal_connect(@{$connects->{$n}});
            }
        }
        if ($combos) {
            for my $n (@$combos) {
                my $combo = $self->{$dialog}->get_widget($n);
                unless ($combo->isa('Gtk2::ComboBoxEntry')) {
                    my $renderer = Gtk2::CellRendererText->new;
                    $combo->pack_start($renderer, TRUE);
                    $combo->add_attribute($renderer, text => 0);
                }
                my $model = Gtk2::ListStore->new('Glib::String');
                $combo->set_model($model);
                $combo->set_text_column(0) if $combo->isa('Gtk2::ComboBoxEntry');
            }
        }
        $boot = 1;
        $widget->set_position('center');
    } else {
        $widget = $self->{$dialog}->get_widget($dialog);
        $widget->move(@{$self->{$dialog.'_position'}}) unless $widget->get('visible');
    }
    $widget->set_title($title);
    $widget->show_all;
    $widget->present;
    return wantarray ? ($self->{$dialog}, $boot) : $self->{$dialog};
}

=pod

=head2 hide_dialog($dialog_class)

Hides the given dialog of this layer object.

Not part of the Layer interface. Used by the glue object for the
introspection dialog.

=cut

## @method hide_dialog($dialog)
# @brief Hide the given (name of a) dialog.
sub hide_dialog {
    my($self, $dialog) = @_;
    $self->{$dialog.'_position'} = [$self->{$dialog}->get_widget($dialog)->get_position];
    $self->{$dialog}->get_widget($dialog)->hide();
}

sub dialog_visible {
    my($self, $dialog) = @_;
    my $d = $self->{$dialog};
    return 0 unless $d;
    return $d->get_widget($dialog)->get('visible');
}

package Gtk2::Ex::Geo::Schema;

sub new {
    my $package = shift;
    my $self = { GeometryType => 'Unknown',
                 Fields => [], };
    bless $self => (ref($package) or $package);
}

sub fields {
    my $schema = shift;
    my @fields = (
        { Name => '.FID', Type => 'Integer' },
        { Name => '.GeometryType', Type => $schema->{GeometryType} }
        );
    push @fields, { Name => '.Z', Type => 'Real' } if $schema->{GeometryType} =~ /25/;
    push @fields, @{$schema->{Fields}};
    return @fields;
}

sub field_names {
    my $schema = shift;
    my @names = ('.FID', '.GeometryType');
    push @names, '.Z' if $schema->{GeometryType} =~ /25/;
    for my $f (@{$schema->{Fields}}) {
        push @names, $f->{Name};
    }
    return @names;
}

sub field {
    my($schema, $field_name) = @_;
    if ($field_name eq '.FID') {
        return { Name => '.FID', Type => 'Integer' };
    }
    if ($field_name eq '.GeometryType') {
        return { Name => '.GeometryType', Type => 'String' };
    }
    if ($field_name eq '.Z') {
        return { Name => '.Z', Type => 'Real' };
    }
    my $i = 0;
    for my $f (@{$schema->{Fields}}) {
        return $f if $field_name eq $f->{Name};
        $i++;
    }
}

sub field_index {
    my($schema, $field_name) = @_;
    my $i = 0;
    for my $f (@{$schema->{Fields}}) {
        if ($field_name eq $f->{Name}) {
            return $i;
        }
        $i++;
    }
}

1;
