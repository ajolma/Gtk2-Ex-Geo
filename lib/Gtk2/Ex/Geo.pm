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

1;
__END__

=head1 NAME

Gtk2::Ex::Geo - An extensible geospatial application toolkit for Gtk2

=head1 SYNOPSIS

 use Glib qw/TRUE FALSE/;
 use Gtk2;
 use Gtk2::Ex::Geo;
 # use any layer classes you may need/have
 
 Gtk2->init;

 # it is a good thing to catch errors and show them to user
 # instead of dying
 Glib->install_exception_handler(\&my_exception_handler);
 
 # construct the main window
 my $window = Gtk2::Window->new;
 
 # construct the glue object, it will contain 
 #   a tree view of the layer objects
 #   a map panel
 #   a toolbar (for menu)
 #   a text entry for commands
 #   a statusbar
 my $gis = Gtk2::Ex::Geo::Glue->new();
 
 # register layer classes
 $gis->register_class('Gtk2::Ex::Geo::Layer');
 
 # construct the layout for the main window

 # the layer list and the map panel will be next to each other
 # thus we will put them in a horizontal box
 my $hbox = Gtk2::HBox->new(FALSE, 0);
 
 # construct a scrolled window and
 # put the layer tree view into it
 my $list = Gtk2::ScrolledWindow->new();
 $list->set_policy("never", "automatic");
 $list->add($gis->{tree_view});

 # add the layer list window
 # and the map panel into the horizonta box
 $hbox->pack_start($list, FALSE, FALSE, 0);
 $hbox->pack_start($gis->{overlay}, TRUE, TRUE, 0);
 
 # construct a vertical box and put
 # the toolbar (menu), the layer list + map, the command line entry, 
 # and the statusbar into it
 my $vbox = Gtk2::VBox->new(FALSE, 0);
 $vbox->pack_start($gis->{toolbar}, FALSE, FALSE, 0);
 $vbox->pack_start($hbox, TRUE, TRUE, 0);
 $vbox->pack_start($gis->{entry}, FALSE, FALSE, 0);
 $vbox->pack_start($gis->{statusbar}, FALSE, FALSE, 0);
 
 # finally put the vertical box into the main window
 # and you're done
 $window->add($vbox);
 $window->signal_connect("destroy", \&close_the_app, [$window, $gis]);
 $window->set_default_size(900, 600);
 $window->show_all;
 
 Gtk2->main;

 sub my_exception_handler {
    my $msg = shift;
    my $dialog = Gtk2::MessageDialog->new(
        undef, 'destroy-with-parent', 'info', 'close', $msg);
    $dialog->signal_connect(
        response => sub {
            my($dialog) = @_;
            $dialog->destroy;
        });
    $dialog->show_all;
    return 1;
 }
 
 sub close_the_app {
     my($window, $gis) = @{$_[1]};
     $gis->close(); # this is for breaking circular references before exiting
     Gtk2->main_quit;
     exit(0);
 }

=head1 DESCRIPTION

Gtk2::Ex::Geo is a toolkit for developing geospatial applications with
Gtk2. It consists of a bootstrap module and several singleton classes.

=head1 CLASSES

=head2 Gtk2::Ex::Geo

The bootstrap module.

=head2 Gtk2::Ex::Geo::Glue

A class for managing map panel, treeview for data layers, menu, text
entry for commands, and statusbar objects. The class manages object to
object interaction and user to object interaction.

=head2 Gtk2::Ex::Geo::Overlay

The class for a map panel, a subclass of Gtk2::ScrolledWindow. This
class contains a map canvas in a scrolled window and a list of layer
objects. Functionality includes redraw, support for selections (point,
line, path, rectangle, polygon, or many of them), zoom, pan, and
conversion between event and world (layer) coordinates.

=head2 Gtk2::Ex::Geo::Canvas

The class for a map canvas, a subclass of Gtk2::Gdk::Pixbuf. This
class is used for constructing a map from a stack of geospatial layer
objects by rendering them sequentially on a pixbuf.

=head2 Gtk2::Ex::Geo::Layer

The root class for geospatial layers. A geospatial layer is typically
a subclass of a class for geospatial data (raster, vector features, or
something else) and of this class. The methods defined in this class
are called when the user interacts with the application.

=head2 Gtk2::Ex::Geo::DialogMaster

A class which maintains a set of Glade dialogs taken from XML in DATA
section.

=head2 Gtk2::Ex::Geo::Dialogs

A subclass of Gtk2::Ex::Geo::DialogMaster. Contains dialogs for
Gtk2::Ex::Geo::Layer.

=head2 Gtk2::Ex::Geo::History

Input history for the command line entry a'la (at least attempting)
GNU history. The command line entry is managed by Glue object with
Gtk2::Entry.

=head2 Gtk2::Ex::Geo::TreeDumper

From L<http://www.asofyet.org/muppet/software/gtk2-perl/treedumper.pl-txt>
For inspecting layer and other objects.

=head1 SHORTCOMINGS

The toolkit is currently pretty ignorant of any spatial reference
system the data sets may have or if they differ from each other.

=head1 AUTHOR

Ari Jolma L<https://github.com/ajolma>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008- Ari Jolma

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl 5 itself.


=cut
