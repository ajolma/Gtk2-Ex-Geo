#** @file Geo.pm
#*

package Gtk2::Ex::Geo;

use strict;
use warnings;
use XSLoader;

use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2;
use Gtk2::Gdk::Keysyms; # in Overlay

use Gtk2::GladeXML;
use Gtk2::Ex::Geo::DialogMaster;

use Gtk2::Ex::Geo::Glue;

BEGIN {
    use Exporter 'import';
    our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );
    our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
    our @EXPORT = qw( );
    our $VERSION = '0.66';
    XSLoader::load( 'Gtk2::Ex::Geo', $VERSION );
}

sub exception_handler {
    my($msg) = @_;
    print STDERR "$msg\n";
}

=head1 NAME

Gtk2::Ex::Geo - The main module to use for geospatial applications

=head1 USAGE

 use Glib qw/TRUE FALSE/;
 use Gtk2;
 use Gtk2::Ex::Geo;
 # use any layer classes you may need/have
 
 Gtk2->init;
 
 # construct the main window
 my $window = Gtk2::Window->new;
 
 # construct the glue object (contains some widgets)
 my $gis = Gtk2::Ex::Geo::Glue->new( main_window => $window );
 
 # register layer classes
 $gis->register_class('Gtk2::Ex::Geo::Layer');
 
 # continue with the main window
 # the layer list and the map will be next to each other
 my $hbox = Gtk2::HBox->new(FALSE, 0);
 
 # layer list
 my $list = Gtk2::ScrolledWindow->new();
 $list->set_policy("never", "automatic");
 $list->add($gis->{tree_view});
 $hbox->pack_start($list, FALSE, FALSE, 0);
 
 # add the map    
 $hbox->pack_start($gis->{overlay}, TRUE, TRUE, 0);
     
 # the toolbar (menu), the layer list + map, the command line entry, 
 # and the statusbar will be on top of each other
 my $vbox = Gtk2::VBox->new(FALSE, 0);
 $vbox->pack_start($gis->{toolbar}, FALSE, FALSE, 0);
 $vbox->pack_start($hbox, TRUE, TRUE, 0);
 $vbox->pack_start($gis->{entry}, FALSE, FALSE, 0);
 $vbox->pack_start($gis->{statusbar}, FALSE, FALSE, 0);
 
 $window->add($vbox);
 $window->signal_connect("destroy", \&close_the_app, [$window, $gis]);
 $window->set_default_size(600,600);
 $window->show_all;
 
 Gtk2->main;
 
 sub close_the_app {
     my($window, $gis) = @{$_[1]};
     $gis->close();
     Gtk2->main_quit;
     exit(0);
 }

=head1 DESCRIPTION

Gtk2::Ex::Geo is a namespace for modules, classes, and widgets for
geospatial applications. The idea is to provide a canvas for
geospatial data, a set of dialogs, and glue code. This package
contains the modules:

B<Gtk2::Ex::Geo> 

The main module to 'use'.

B<Gtk2::Ex::Geo::Canvas>

A subclass of Gtk2::Gdk::Pixbuf. Constructs a pixbuf with a map from a
stack of geospatial layer objects by calling the 'render' method for
each $layer.

B<Gtk2::Ex::Geo::Overlay>

A subclass of Gtk2::ScrolledWindow. A canvas in a scrolled
window. Contains a list of layer objects. Functionality includes
redraw, support for selections (point, line, path, rectangle, polygon,
or many of them), zoom, pan, and conversion between event and world
(layer) coordinates.

B<Gtk2::Ex::Geo::Layer>

The root class for geospatial layers. A geospatial layer is a
typically a subclass of a geospatial data (raster, vector features, or
something else) and of this class. The idea is that this class
contains visualization information (transparency, palette, colors,
symbology, label placement, etc) for the data. Contains many callbacks
that are fired as a result of user using context menu, making a
selection, etc. Uses layer dialogs.

B<Gtk2::Ex::Geo::DialogMaster>

A class which maintains a set of Glade dialogs taken from XML in DATA
section.

B<Gtk2::Ex::Geo::Dialogs>

A subclass of Gtk2::Ex::Geo::DialogMaster. Contains dialogs for
Gtk2::Ex::Geo::Layer.

B<Gtk2::Ex::Geo::Glue>

Typically a singleton class for an object, which manages a
Gtk2::Ex::Geo::Overlay widget, a Gtk2::TreeView widgets, and other
widgets of a geospatial application. The object also takes care of
popping up context menus and other things.

B<Gtk2::Ex::Geo::History>

Input history for the command line entry a'la (at least attempting)
GNU history. The command line entry is managed by Glue object with
Gtk2::Entry.

B<Gtk2::Ex::Geo::TreeDumper>

From http://www.asofyet.org/muppet/software/gtk2-perl/treedumper.pl-txt
For inspecting layer and other objects.

=head1 DOCUMENTATION

The documentation of Gtk2::Ex::Geo is included into the source code in
doxygen format. The documentation can be generated in HTML, LaTeX, and
other formats using the doxygen executable and the perl doxygen
filter.

1) http://www.stack.nl/~dimitri/doxygen
2) http://search.cpan.org/~jordan/Doxygen-Filter-Perl/
3) http://ajolma.net/

=cut

1;
