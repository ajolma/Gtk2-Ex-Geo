=pod

=head1 NAME

Gtk2::Ex::Geo::ColorPalette - A class for value(s) -> color converter

This module is a part of the Gtk2::Ex::Geo toolkit.

=head1 SYNOPSIS

    my $palette = Gtk2::Ex::Geo::ColorPalette::Table->new( file_name => 'palette.clr' );
    my $style = Gtk2::Ex::Geo::Style->new( color_table => $palette );
    $raster_layer->assign_style($style, 'cell value');

or

    my $palette = Gtk2::Ex::Geo::ColorPalette::ShadesOfGray( min_value => 10, max_value => 300 );
    my @gray = $palette->color(245);

=head1 DESCRIPTION

Gtk2::Ex::Geo::ColorPalette is a tree of classes, which can convert a
property value (or property values) into a color. The simplest color
palette is a single color, while a complex palette may use several
property values to compute a color.

=cut

package Gtk2::Ex::Geo::ColorPalette;

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

use vars qw/$COLOR_CELL_SIZE/;

$COLOR_CELL_SIZE = 20;

sub order {
}

sub readable_class_name {
}

sub is_table_like {
}

sub output_is_hue {
}

sub new {
    my $class = shift;
    my %params = @_;
    my $self = $params{self} ? $params{self} : {};
    if ($params{readable_class_name}) {
        $class = undef;
        my $subclass_names = Class::Inspector->subclasses( 'Gtk2::Ex::Geo::ColorPalette' );
        for my $subclass (@$subclass_names) {
            my $name = eval $subclass.'->readable_class_name';
            if ($name && $name eq $params{readable_class_name}) {
                $class = $subclass;
                last;
            }
        }
        croak "Unknown color palette class: $params{readable_class_name}." unless $class;
    }
    bless $self => (ref($class) or $class);
    $self->initialize(@_);
    return $self;
}

sub initialize {
    my $self = shift;
    my %params = @_;
    $self->{property_name} = undef;
    $self->{property_name} = $params{property_name};
    $self->{property_type} = undef;
    $self->{property_type} = $params{property_type};
    $self->{style} = undef;
    $self->{style} = $params{style};
}


sub value_range {
}

sub color { # get or set, if set, the last four params are the color
}

sub add_color { # the last four params are the color
}

sub remove_color_at {
}

sub property_value_at { # property value at index for table like palettes
}

sub set_color_view {
    my ($self, $view) = @_;
    $self->{color_view} = $view;
    $self->{model} = undef;
    my $model = $self->{color_view}->get_model;
    if ($model) {
        for my $col ($self->{color_view}->get_columns) {
            $self->{color_view}->remove_column($col);
        }
        $model->clear;
    }
}

sub prepare_model {
    my ($self) = @_;
    return unless $self->{color_view};
    my $model = $self->{color_view}->get_model;
    $model->clear if $model;
    for my $col ($self->{color_view}->get_columns) {
        $self->{color_view}->remove_column($col);
    }
}

sub update_model {
}

sub set_color_to_model {
    my ($self, $iter, $value, @color) = @_;
    my @set = ($iter);
    my $j = 0;
    push @set, ($j++, $value) if defined $value;
    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    my $pb = Gtk2::Gdk::Pixbuf->new('rgb', 0, 8, $size, $size);
    $pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);
    push @set, ($j++, $pb);
    for my $k (0..3) {
	push @set, ($j++, $color[$k]);
    }
    $self->{model}->set(@set);
}

sub view_changed {
}

package Gtk2::Ex::Geo::ColorPalette::SingleColor;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette );

sub order {
    return 1;
}

sub readable_class_name {
    return 'Single color';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{color} = [0, 0, 0, 255];
    @{$self->{color}} = @{$params{color}} if $params{color};
    $self->{property_name} = undef;
    $self->{property_type} = undef;
}

sub color {
    my $self = shift;
    @{$self->{color}} = splice(@_, -4, 4) if @_ > 3;
    return @{$self->{color}};
}

sub prepare_model {
    my ($self) = @_;
    return unless $self->{color_view};
    $self->SUPER::prepare_model;

    my $model = Gtk2::TreeStore->new(qw/Gtk2::Gdk::Pixbuf Glib::Int Glib::Int Glib::Int Glib::Int/);
    $self->{color_view}->set_model($model);

    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    my $i = 0;
    my $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($size-2, $size-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('Color', $cell, pixbuf => $i++);
    $self->{color_view}->append_column($column);

    for my $c ('Red','Green','Blue','Alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&view_changed, [$self, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$self->{color_view}->append_column($column);
    }
    $self->{color_view}->get_selection->set_mode('multiple');

    $self->{model} = $model;
    $self->update_model;
}

sub update_model {
    my ($self) = @_;
    return unless $self->{model};
    $self->{model}->clear;
    my $iter = $self->{model}->append(undef);
    $self->set_color_to_model($iter, undef, @{$self->{color}});
}

sub view_changed {
    my ($cell, $path, $new_value, $data) = @_;
    my ($self, $column) = @$data;
    my @color = $self->color;
    $color[$column] = $new_value;
    $self->color(@color);
    $self->update_model;
}

package Gtk2::Ex::Geo::ColorPalette::ValueRange;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette );

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{min_value} = undef;
    $self->{min_value} = $params{min_value} if $params{min_value};
    $self->{max_value} = undef;
    $self->{max_value} = $params{max_value} if $params{max_value};
}

sub property {
    my $self = shift;
    $self->{min_value} = undef;
    $self->{max_value} = undef;
    $self->SUPER::property(@_);
}

sub valid_property_type {
    my $self = shift;
    my $type = shift;
    return unless $type;
    return $type eq 'Integer' || $type eq 'Real';
}

sub value_range {
    my $self = shift;
    ($self->{min_value}, $self->{max_value}) = @_ if @_;
    return ($self->{min_value}, $self->{max_value});
}

sub prepare_model {
    my ($self) = @_;
    return unless $self->{color_view};
    $self->SUPER::prepare_model;

    my $type = $self->property_type_for_GTK;
    return unless $type;
    my $model = Gtk2::TreeStore->new('Gtk2::Gdk::Pixbuf', 'Glib::'.$type);
    $self->{color_view}->set_model($model);

    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    my $i = 0;
    my $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($size-2, $size-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $self->{color_view}->append_column($column);

    $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 0);
    $column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
    $self->{color_view}->append_column($column);

    $self->{model} = $model;
    $self->update_model;
}

sub update_model {
    my ($self) = @_;
    return unless $self->{model};
    $self->{model}->clear;
    my ($min, $max) = $self->value_range;
    return unless defined $min && $min ne '' && defined $max && $max ne '';
    my $delta = ($max-$min)/14;
    return if $delta <= 0;
    my $x = $max;
    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    for my $i (1..15) {
	my $iter = $self->{model}->append(undef);
	my @set = ($iter);
	my $alpha = 255;
	my @color = $self->color($x);
        push @color, $alpha;
        my $pb = Gtk2::Gdk::Pixbuf->new('rgb', 0, 8, $size, $size);
	$pb->fill($color[0] << 24 | $color[1] << 16 | $color[2] << 8);
	my $j = 0;
	push @set, ($j++, $pb);
	push @set, ($j++, $x);
	$self->{model}->set(@set);
	$x -= $delta;
	$x = $min if $x < $min;
    }
}

package Gtk2::Ex::Geo::ColorPalette::ShadesOfGray;
use locale;
use Graphics::ColorUtils qw /:all/;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::ValueRange );

sub order {
    return 2;
}

sub readable_class_name {
    return 'Shades of gray';
}

sub color {
    my ($self, $value) = @_;
    my $min = $self->{min_value};
    my $max = $self->{max_value};
    my $invert_palette = $max < $min;
    my $h = 0;
    my $s = 0;
    my $v = ($value - $min)/($max - $min);
    $v = 1 - $v if $invert_palette;
    my @color = hsv2rgb($h, $s, $v);
    return @color;
}

package Gtk2::Ex::Geo::ColorPalette::HueRegion;
use locale;
use Graphics::ColorUtils qw /:all/;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::ValueRange );

sub order {
    return 3;
}

sub readable_class_name {
    return 'Hue region';
}

sub output_is_hue {
    return 1;
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{min_hue} = 235;
    $self->{min_hue} = $params{min_hue} if $params{min_hue};
    $self->{max_hue} = 0;
    $self->{max_hue} = $params{max_hue} if $params{max_hue};
    $self->{hue_increment} = -1;
    $self->{hue_increment} = $params{hue_increment} if $params{hue_increment};
}

sub color {
    my ($self, $value) = @_;
    my $min = $self->{min_value};
    my $max = $self->{max_value};
    my $hue_min = $self->{min_hue};
    my $hue_max = $self->{max_hue};
    if ($self->{hue_increment} == 1) {
	$hue_max += 360 if $hue_max < $hue_min;
    } else {
	$hue_max -= 360 if $hue_max > $hue_min;
    }
    my $h = int($hue_min + ($value - $min)/($max-$min) * ($hue_max-$hue_min) + 0.5);
    $h -= 360 if $h > 360;
    $h += 360 if $h < 0;
    my $s = 1;
    my $v = 1;
    my @color = hsv2rgb($h, $s, $v);
    return @color;
}

sub hue_range {
    my $self = shift;
    ($self->{min_hue}, $self->{max_hue}, $self->{hue_increment}) = @_ if @_;
    return ($self->{min_hue}, $self->{max_hue}, $self->{hue_increment});
}

package Gtk2::Ex::Geo::ColorPalette::Table;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette );

sub is_table_like {
    return 1;
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
}

sub prepare_model {
    my ($self) = @_;
    return unless $self->{color_view};
    $self->SUPER::prepare_model;

    my $type = $self->property_type_for_GTK;
    return unless $type;
    my $model = Gtk2::TreeStore->new("Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");
    $self->{color_view}->set_model($model);

    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    my $i = 0;
    my $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 1);
    $cell->signal_connect(edited => \&view_changed, [$self, $i]);
    my $column = Gtk2::TreeViewColumn->new_with_attributes($self->column_header, $cell, text => $i++);
    $self->{color_view}->append_column($column);

    $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($size-2, $size-2);
    $column = Gtk2::TreeViewColumn->new_with_attributes('Color', $cell, pixbuf => $i++);
    $self->{color_view}->append_column($column);

    for my $c ('Red','Green','Blue','Alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&view_changed, [$self, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$self->{color_view}->append_column($column);
    }
    $self->{color_view}->get_selection->set_mode('multiple');

    $self->{model} = $model;
    $self->update_model;
}

sub view_changed {
    my ($cell, $path, $new_value, $data) = @_;
    my ($self, $column) = @$data;
    if ($column == 0) {
        $self->property_value_at($path, $new_value);
    } else {
        # color changed
        my $x = $self->property_value_at($path);
        $column--;
        my @color = $self->color($x);
        $color[$column] = $new_value;
        $self->color($x, @color);
    }
    $self->update_model;
}

package Gtk2::Ex::Geo::ColorPalette::Table::Lookup;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::Table );

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
    $self->{table} = {};
    $self->{table} = $params{table} if $params{table}; # should copy
}

sub property {
    my $self = shift;
    $self->{table} = {};
    $self->SUPER::property(@_);
}

sub valid_property_type {
    my $self = shift;
    my $type = shift;
    return unless $type;
    return $type eq 'Integer' || $type eq 'String';
}

sub color {
    my $self = shift;
    my $key = shift;
    if (@_ > 3) {
        $self->{table}->{$key} = [@_];
    }
    return @{$self->{table}->{$key}} if exists $self->{table}->{$key};
}

sub new_property_value {
    my $self = shift;
    if ($self->{property_type} eq 'String') {
        return 'Change this.';
    } else {
        my @table = sort {$a <=> $b} keys %{$self->{table}};
        return 0 unless @table;
        return $table[$#table]+1;
    }
}

sub add_color {
    my $self = shift;
    my $key = shift;
    $self->{table}->{$key} = [@_];
}

sub remove_color_at {
    my $self = shift;
    my $value = shift;
    delete $self->{table}->{$value};
}

sub property_value_at {
    my $self = shift;
    my $index = shift;
    my @table;
    if (@_) {
        my $new_key = shift;
        my $key = $self->property_value_at($index);
        my $tmp = $self->{table}->{$key};
        delete $self->{table}->{$key};
        $self->{table}->{$new_key} = $tmp;
    }
    if ($self->{property_type} eq 'String') {
        @table = sort keys %{$self->{table}};
    } else {
        @table = sort {$a <=> $b} keys %{$self->{table}};
    }
    return $table[$index];
}

sub column_header {
    return 'Key';
}

sub update_model {
    my ($self) = @_;
    return unless $self->{model};
    $self->{model}->clear;
    if ($self->{property_type} eq 'String') {
        for my $key (sort keys %{$self->{table}}) {
            my $iter = $self->{model}->append(undef);
            my @color = $self->color($key);
            $self->set_color_to_model($iter, $key, @color);
        }
    } else {
        for my $key (sort {$a <=> $b} keys %{$self->{table}}) {
            my $iter = $self->{model}->append(undef);
            my @color = $self->color($key);
            $self->set_color_to_model($iter, $key, @color);
        }
    }
}

package Gtk2::Ex::Geo::ColorPalette::Table::Bins;
use locale;
use Carp;
use bigrat;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::Table );

sub order {
    return 5;
}

sub readable_class_name {
    return 'Color bins';
}

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{table} = [[0,0,0,0,255],[0,255,255,255,255]];
    $self->{table} = Clone::clone($params{table}) if $params{table};
}

sub property {
    my $self = shift;
    $self->{table} = [[0,0,0,0,255],[0,255,255,255,255]];
    $self->SUPER::property(@_);
}

sub valid_property_type {
    my $self = shift;
    my $type = shift;
    return unless $type;
    return $type eq 'Integer' || $type eq 'Real';
}

sub property_type_for_GTK {
    return 'String';
}

sub index {
    my ($self, $value) = @_;
    my $table = $self->{table};
    return 0 if $value <= $table->[0]->[0];
    my $index = 1;
    while ($index < $#$table) {
        return $index if $value <= $table->[$index]->[0];
        $index++;
    }
    return $index;
}

sub color {
    my $self = shift;
    my $value = shift;
    $value = $self->{property_type} eq 'Integer' ? int($value) : $value;
    my $index = $self->index($value);
    if (@_ > 3) {
        $self->{table}->[$index] = [$value, @_];
    }
    return @{$self->{table}->[$index]}[1..4];
}

sub new_property_value {
    my $self = shift;
    return $self->{table}->[0]->[0]-1;
}

sub organize {
    my $self = shift;
    my @sort;
    my $n = @{$self->{table}}-1;
    for (my $i = 0; $i < $n; $i++) {
        push @sort, [$self->{table}->[$i]->[0], $i];
    }
    my $last = $self->{table}->[$n];
    @sort = sort {$a->[0]<=>$b->[0]} @sort;
    my @new;
    for my $value_and_index (@sort) {
        push @new, $self->{table}->[$value_and_index->[1]];
    }
    push @new, $last;
    $self->{table} = \@new;
}

sub add_color {
    my $self = shift;
    my $value = shift;
    $value = $self->{property_type} eq 'Integer' ? int($value) : $value+0;
    my $n = @{$self->{table}};
    unshift @{$self->{table}}, [$value, @_];
    $n = @{$self->{table}};
    $self->organize;
    $n = @{$self->{table}};
}

sub remove_color_at {
    my $self = shift;
    my $value = shift;
    my $table = $self->{table};
    return if @$table == 2;
    my $index = $self->index($value);
    splice @$table, $index, 1;
}

sub property_value_at {
    my $self = shift;
    my $index = shift;
    if (@_ and $index < $#{$self->{table}}) {
        my $new_value = POSIX::strtod(shift);
        $new_value = $self->{property_type} eq 'Integer' ? int($new_value) : $new_value;
        my @color = @{$self->{table}->[$index]}[1..4];
        $self->{table}->[$index] = [$new_value, @color];
        $self->organize;
    }
    return 'inf' if $index == $#{$self->{table}};
    return $self->{table}->[$index]->[0];
}

sub column_header {
    return 'Bin';
}

sub update_model {
    my ($self) = @_;
    return unless $self->{model};
    $self->{model}->clear;
    my $i = 0;
    my $n = @{$self->{table}};
    for my $value_and_color (@{$self->{table}}) {
        my $iter = $self->{model}->append(undef);
        $value_and_color->[0] = 'inf' if $i == $n-1;
        $self->set_color_to_model($iter, @$value_and_color);
        $i++;
    }
}

package Gtk2::Ex::Geo::ColorPalette::ValueRange::RedChannel;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::ValueRange );

sub order {
    return 6;
}

sub readable_class_name {
    return 'Red channel';
}

sub color {
    my ($self, $value) = @_;
    my $min = $self->{min_value};
    my $max = $self->{max_value};
    my $r = int(($value - $min)/($max - $min) * 255 + 0.5);
    return ($r, 0, 0);
}

package Gtk2::Ex::Geo::ColorPalette::ValueRange::GreenChannel;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::ValueRange );

sub order {
    return 7;
}

sub readable_class_name {
    return 'Green channel';
}

sub color {
    my ($self, $value) = @_;
    my $min = $self->{min_value};
    my $max = $self->{max_value};
    my $g = int(($value - $min)/($max - $min) * 255 + 0.5);
    return (0, $g, 0);
}

package Gtk2::Ex::Geo::ColorPalette::ValueRange::BlueChannel;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::ValueRange );

sub order {
    return 8;
}

sub readable_class_name {
    return 'Blue channel';
}

sub color {
    my ($self, $value) = @_;
    my $min = $self->{min_value};
    my $max = $self->{max_value};
    my $b = int(($value - $min)/($max - $min) * 255 + 0.5);
    return (0, 0, $b);
}

1;
