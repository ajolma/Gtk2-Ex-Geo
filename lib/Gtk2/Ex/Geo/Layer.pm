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
use locale;
use Scalar::Util qw(blessed);
use Carp;
use Class::Inspector;
use Glib qw /TRUE FALSE/;
use Gtk2::Ex::Geo::Style;
use Gtk2::Ex::Geo::ColorPalette;
use Gtk2::Ex::Geo::Symbolizer;
use Gtk2::Ex::Geo::Dialogs;
use Gtk2::Ex::Geo::Dialogs::Symbolizing;
use Gtk2::Ex::Geo::Dialogs::Coloring;
use Gtk2::Ex::Geo::Dialogs::Labeling;

use vars qw/%GEOMETRY_TYPES %PALETTE_TYPES %SYMBOLIZER_TYPES/;

BEGIN {
    use Exporter 'import';
    our %EXPORT_TAGS = ( 'all' => [ qw(%GEOMETRY_TYPES) ] );
    our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
    unless (%GEOMETRY_TYPES) {
        my $subclass_names = Class::Inspector->subclasses( 'Geo::OGC::Geometry' );
        for my $class (@$subclass_names) {
            my $type = eval $class.'->GeometryType';
            $GEOMETRY_TYPES{$type} = 1;
        }
    }
    unless (%PALETTE_TYPES) {
        my $name = Gtk2::Ex::Geo::ColorPalette->readable_class_name;
        my $order = Gtk2::Ex::Geo::ColorPalette->order;
        $PALETTE_TYPES{$name} = $order if $name;
        my $subclass_names = Class::Inspector->subclasses( 'Gtk2::Ex::Geo::ColorPalette' );
        for my $class (@$subclass_names) {
            my $name = eval $class.'->readable_class_name';
            my $order = eval $class.'->order';
            next unless $name;
            $PALETTE_TYPES{$name} = $order;
        }
    }
    unless (%SYMBOLIZER_TYPES) {
        my $name = Gtk2::Ex::Geo::Symbolizer->readable_class_name;
        my $order = Gtk2::Ex::Geo::Symbolizer->order;
        $SYMBOLIZER_TYPES{$name} = $order if $name;
        my $subclass_names = Class::Inspector->subclasses( 'Gtk2::Ex::Geo::Symbolizer' );
        for my $class (@$subclass_names) {
            my $name = eval $class.'->readable_class_name';
            my $order = eval $class.'->order';
            next unless $name;
            $SYMBOLIZER_TYPES{$name} = $order;
        }
    }
}

=pod

=head1 LAYER INTERFACE

These subroutines are invoked by the glue or overlay objects on layer
objects as methods or on the layer class as package subroutines.

Note: currently the glue object uses the key _tree_index and assumes
that the layer object is a hash reference.

Note: the behavior of the reference implementation (see the next
section) for the methods listed in this section is described in this
section.

=head2 registration($glue)

Package subroutine to obtain information about the layer class in an
anonymous hash.

$glue is the glue object (currently not used)

Currently the following keywords are recognized from the returned
hash:

=over

=item dialogs

A dialog manager. Typically an object a subclass of
Gtk2::Ex::Geo::DialogMaster. In general and if given, this should be
an object, which can produce a dialog widget for general use within
the toolkit by a method call get_dialog($dialog_name).

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

The reference implementation returns a Gtk2::Ex::Geo::Dialogs object,
which is a singleton which manages dialog classes coloring_dialog,
labels_dialog, and symbols_dialog that are defined in the DATA of the
package Gtk2::Ex::Geo::Dialogs.

=cut

sub registration {
    my($glue) = @_;
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

The reference implementation defines menu items 'Unselect all',
'Symbolizing', 'Coloring', 'Labeling', 'Inspect', and
'Properties'. 'Unselect all' leads to a call of 'select' method
without parameters. 'Inspect' leads to a call of 'inspect' method of
the Gtk2::Ex::Geo::Glue class with parameters from 'inspect_data' and
'name' methods. 'Properties' leads to a call of
'open_properties_dialog' method. The 'Symbolizing', 'Coloring', and
'Labeling' items lead to submenus made from the names of the geometric
properties, and eventually respective dialog calls.

=cut

sub menu_items {
    my($self) = @_;
    my @symbolizing_submenu;
    my @coloring_submenu;
    my @labeling_submenu;
    my $properties = $self->schema()->{Properties};
    for my $name (sort keys %$properties) {
        next unless $GEOMETRY_TYPES{$properties->{$name}->{Type}};
        my $item = "For property <i>".$name."</i>";
        push @symbolizing_submenu, $item;
        push @symbolizing_submenu, sub {
            my($self, $gui) = @{$_[1]};
            $self->open_symbolizing_dialog($name, $gui);
        };
        push @coloring_submenu, $item;
        push @coloring_submenu, sub {
            my($self, $gui) = @{$_[1]};
            $self->open_coloring_dialog($name, $gui);
        };
        push @labeling_submenu, $item;
        push @labeling_submenu, sub {
            my($self, $gui) = @{$_[1]};
            $self->open_labeling_dialog($name, $gui);
        };
    }
    my @items;
    push @items, (
        '_Unselect all' => sub {
            my($self, $gui) = @{$_[1]};
            $self->select;
            $gui->{overlay}->update_image;
            $self->open_features_dialog($gui, 1);
        });
    push @items, ('_Symbolizing...' => \@symbolizing_submenu) if @symbolizing_submenu;
    push @items, ('_Coloring...' => \@coloring_submenu) if @coloring_submenu;
    push @items, ('_Labeling...' => \@labeling_submenu) if @labeling_submenu;
    push @items, (
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

The reference implementation finds all Gtk2::GladeXML objects within
this layer object and destroys the widget in each of them. The method
assumes that the layer property and the widget name are the same. See
also bootstrap_dialog.

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

The reference implementation returns '';

=cut

sub type {
    return '';
}

=pod

=head2 name($name)

Get or set the name of the layer object.

=cut

sub name {
    my($self, $name) = @_;
    $self->{name} = $name if defined $name;
    return $self->{name};
}

=pod

=head2 world()

The bounding box (a list min x, min y, max x, max y) of the layer object.

=cut

=pod

=head2 alpha($alpha)

Get or set the alpha (transparency) of the layer. Alpha is an integer
value between 0 and 255.

=cut

sub alpha {
    my($self, $alpha) = @_;
    if (defined $alpha) {
        $alpha = 0 if $alpha < 0;
        $alpha = 255 if $alpha > 255;
        $self->{alpha} = $alpha;
    }
    $self->{alpha};
}

=pod

=head2 visible($visibility)

Get or set the visibility state of this layer.

=cut

sub visible {
    my $self = shift;
    $self->{visible} = shift if @_;
    return $self->{visible};
}

=pod

=head2 got_focus($glue)

A callback, which is invoked when this layer gets the cursor in the
layer list.

=head2 lost_focus($glue)

A callback, which is invoked when the cursor is moved away from this
layer in the layer list.

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
        $self->{selected_features} = [];
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

The reference implementation returns ''.

=cut

sub statusbar_info {
    my($self, $x, $y) = @_;
    return '';
}

=pod

=head1 REFERENCE IMPLEMENTATION

The goal of the reference implementation of a Gtk2::Ex::Geo::Layer is
to be useful as a root class for common geospatial layer classes.

=head2 new(%params)

Creates a new object or re-blesses the 'self' parameter into a given
class and calls defaults.

=cut

sub new {
    my($class, %params) = @_;
    my $self = $params{self} ? $params{self} : {};
    bless $self => (ref($class) or $class);
    $self->initialize(%params);
    $self->{glue} = $params{glue};
    return $self;
}

=pod

=head2 initialize(%params)

Sets the properties of this layer object to reasonable defaults or to
values given as parameters. The properties of a layer are currently:

=cut


sub initialize {
    my($self, %params) = @_;

    # set defaults for all, order of preference is: 
    # user given as constructor parameter
    # subclass default
    # default as defined here

    my %DEFAULTS = (name => '', alpha => 255, visible => 1);

    for my $property (keys %DEFAULTS) {
        $self->{$property} = $DEFAULTS{$property} unless exists $self->{$property};
        $self->{$property} = $params{$property} if exists $params{$property};
    }
    
}

sub DESTROY {
    my $self = shift;
    $self->close();
}

=pod

=head2 schema()

Returns the schema of this layer as an anonymous hash. The schema
should contain key 'Properties', whose value should be a hash of hashes
(properties). The key of each property should be the name of the property and
the property itself should have a key 'Type'.

=cut

sub schema {
    return { Properties => {} };
}

sub selected_features {
    my($self, $selected) = @_;
    if (@_ > 1) {
        $self->{selected_features} = $selected;
    }
    return $self->{selected_features};
}

sub features {
}

sub value_range {
    my ($self, $property) = @_;
    return (0, 0);
}

sub inspect_data {
    my $self = shift;
    return $self;
}

=pod

=head2 palette_types()

Package subroutine.

The list of palette types that this class supports. The list is used
in the coloring dialog box.

=cut

sub palette_types {
    return sort {$PALETTE_TYPES{$a} <=> $PALETTE_TYPES{$b}} keys %PALETTE_TYPES;
}

sub symbolizer_types {
    return sort {$SYMBOLIZER_TYPES{$a} <=> $SYMBOLIZER_TYPES{$b}} keys %SYMBOLIZER_TYPES;
}

=pod

=head1 DIALOGS

The Gtk2::Ex::Geo::Layer class uses five dialogs: coloring,
colors_from, labeling, and symbolizing. These are stored and managed
by the Gtk2::Ex::Geo::Dialogs package.

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

=head2 open_symbolizing_dialog($glue)

=cut

sub open_symbolizing_dialog {
    my($self, $property, $glue) = @_;
    $self->{styles}->{$property} = Gtk2::Ex::Geo::Style->new(glue => $glue,
                                                             layer => $self, 
                                                             property => $property) unless $self->{styles}->{$property};
    $self->{styles}->{$property}->{symbol_dialog}->open;
}

=pod

=head2 open_coloring_dialog($glue)

=cut

sub open_coloring_dialog {
    my($self, $property, $glue) = @_;
    my $styles = $self->{styles};
    $styles->{$property} = Gtk2::Ex::Geo::Style->new(glue => $glue,
                                                     layer => $self, 
                                                     property => $property) unless $styles->{$property};
    $styles->{$property}->{color_dialog}->open;
}

=pod

=head2 open_labeling_dialog($glue)

=cut

sub open_labeling_dialog {
    my($self, $property, $glue) = @_;
    $self->{styles}->{$property} = Gtk2::Ex::Geo::Style->new(glue => $glue,
                                                             layer => $self, 
                                                             property => $property) unless $self->{styles}->{$property};
    $self->{styles}->{$property}->{label_dialog}->open;
}

1;
