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
use Glib qw/TRUE FALSE/;

use vars qw/$COLOR_CELL_SIZE/;

$COLOR_CELL_SIZE = 20;

sub new {
    my $class = shift;
    my %params = @_;
    my $self = $params{self} ? $params{self} : {};
    if ($params{readable_class_name}) {
        if ($params{readable_class_name} ne Gtk2::Ex::Geo::ColorPalette->readable_class_name) {
            $class = undef;
            my $subclass_names = Class::Inspector->subclasses( 'Gtk2::Ex::Geo::ColorPalette' );
            for my $subclass (@$subclass_names) {
                my $name = eval $subclass.'->readable_class_name';
                if ($name eq $params{readable_class_name}) {
                    $class = $subclass;
                    last;
                }
            }
            croak "Unknown color palette class: $params{readable_class_name}." unless $class;
        }
    }
    bless $self => (ref($class) or $class);
    $self->initialize(@_);
    return $self;
}

sub initialize {
    my $self = shift;
    my %params = @_;
    $self->{key_type} = undef unless $self->{key_type};
    $self->{key_type} = $params{key_type};
}

sub order {
    return 1;
}

sub key_type {
    my $self = shift;
    if (@_) {
        my $type = shift;
        croak "Unknown key type: '$type'." unless $type eq 'Integer' or $type eq 'Real' or $type eq 'String';
        my $changed = (defined $self->{key_type} and $self->{key_type} ne $type);
        $self->{key_type} = $type;
        $self->set_up_mvc if $changed;
    }
    return $self->{key_type};
}

sub key_type_for_GTK {
    my $self = shift;
    my $type = $self->key_type;
    return 'Int' if $type eq 'Integer';
    return 'Double' if $type eq 'Real';
    return 'String' if $type eq 'String';
    return '';
}

sub readable_class_name {
    return '';
}

sub supports_string_keys {
    return 0;
}

sub supports_integer_keys {
    return 0;
}

sub supports_real_keys {
    return 0;
}

sub has_finite_keys {
    return undef;
}

sub output_is_hue {
    return 0;
}

sub color { # get or set, if set, the last four params are the color
}

sub add_color { # the last four params are the color
}

sub remove_color {
}

sub key_at { # key or value at index for table like palettes
}

sub set_mvc {
    my ($self, $mvc) = @_;
    $self->{mvc} = $mvc;
}

sub set_up_mvc {
    my ($self) = @_;
    return unless $self->{mvc};
}

sub set_to_model {
    my ($self) = @_;
    return unless $self->{model};
}

sub add_to_model {
    my ($self) = @_;
    return unless $self->{model};
}

sub edit_color {
    my ($self) = @_;
    return unless $self->{mvc};
    
    my $selection = $self->{mvc}->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;

    my $i = $selected[0]->to_string;
    my $key = $self->key_at($i);
    my @color = $self->color($key);
	    
    my $d = Gtk2::ColorSelectionDialog->new('Choose a color.');
    my $s = $d->colorsel;
	    
    $s->set_has_opacity_control(1);
    my $c = Gtk2::Gdk::Color->new($color[0]*257, $color[1]*257, $color[2]*257);
    $s->set_current_color($c);
    $s->set_current_alpha($color[3]*257);

    my $ok = $d->run eq 'ok';
    if ($ok) {
	$d->destroy;
	$c = $s->get_current_color;
	@color = (int($c->red/257+0.5),int($c->green/257+0.5),int($c->blue/257+0.5));
	$color[3] = int($s->get_current_alpha()/257+0.5);

        for my $selected (@selected) {
            my $i = $selected->to_string;
            my $key = $self->key_at($i);
            $self->color($key, @color);
        } 

    } else {
	$d->destroy;
    }
    
    for my $selected (@selected) {
	$selection->select_path($selected);
    }

    $self->set_up_mvc if $ok;
}

sub delete_color {
    my ($self) = @_;
    return unless $self->{mvc};

    my $selection = $self->{mvc}->get_selection;
    my @selected = $selection->get_selected_rows;
    return unless @selected;

    my @to_remove;
    for my $selected (@selected) {
        my $i = $selected->to_string;
        push @to_remove, $self->key_at($i);
    } 

    for my $key (@to_remove) {
        $self->remove_color($key);
    }
    
    $self->set_up_mvc;
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

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{color} = [0, 0, 0, 255] unless $self->{color};
    @{$self->{color}} = @{$params{color}} if $params{color};
    $self->{key_type} => undef
}

sub key_type {
    my $self = shift;
    if (@_) {
        croak "Setting key type not supported.";
    }
    return $self->{key_type};
}

sub readable_class_name {
    return 'Single color';
}

sub color {
    my $self = shift;
    @{$self->{color}} = splice(@_, -4, 4) if @_ > 3;
    return @{$self->{color}};
}

sub set_up_mvc {
    my ($self) = @_;
    my $model = $self->{mvc}->get_model;
    $model->clear if $model;

    $model = Gtk2::TreeStore->new(qw/Gtk2::Gdk::Pixbuf Glib::Int Glib::Int Glib::Int Glib::Int/);
    $self->{mvc}->set_model($model);
    for my $col ($self->{mvc}->get_columns) {
	$self->{mvc}->remove_column($col);
    }

    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    my $i = 0;
    my $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($size-2, $size-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('Color', $cell, pixbuf => $i++);
    $self->{mvc}->append_column($column);

    for my $c ('Red','Green','Blue','Alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&view_changed, [$self, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$self->{mvc}->append_column($column);
    }
    $self->{mvc}->get_selection->set_mode('multiple');

    $self->{model} = $model;
    $self->set_model();
}

sub set_model {
    my ($self) = @_;
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
    $self->set_model;
}

package Gtk2::Ex::Geo::ColorPalette::ValueRange;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette );

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{min_value} = undef unless defined $self->{min_value};
    $self->{min_value} = $params{min_value} if $params{min_value};
    $self->{max_value} = undef unless defined $self->{max_value};
    $self->{max_value} = $params{max_value} if $params{max_value};
}

sub key_type {
    my $self = shift;
    if (@_) {
        my ($type) = @_;
        croak "Unsupported key type: '$type'." unless $type eq 'Integer' or $type eq 'Real';
    }
    $self->SUPER::key_type(@_);
}

sub readable_class_name {
    return ''; # virtual class
}

sub supports_integer_keys {
    return 1;
}

sub supports_real_keys {
    return 1;
}

sub has_finite_keys {
    return 0;
}

sub output_is_hue {
    return 0;
}

sub value_range {
    my $self = shift;
    if (@_) {
        ($self->{min_value}, $self->{max_value}) = @_;
        $self->set_up_mvc;
    }
    return ($self->{min_value}, $self->{max_value});
}

sub set_up_mvc {
    my ($self) = @_;
    print STDERR "set up mvc $self\n";
    return unless $self->{mvc};
    my $model = $self->{mvc}->get_model;
    $model->clear if $model;

    my $type = $self->key_type_for_GTK;
    $model = Gtk2::TreeStore->new('Gtk2::Gdk::Pixbuf', 'Glib::'.$type);
    $self->{mvc}->set_model($model);
    for my $col ($self->{mvc}->get_columns) {
	$self->{mvc}->remove_column($col);
    }

    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    my $i = 0;
    my $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($size-2, $size-2);
    my $column = Gtk2::TreeViewColumn->new_with_attributes('color', $cell, pixbuf => $i++);
    $self->{mvc}->append_column($column);

    $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 0);
    $column = Gtk2::TreeViewColumn->new_with_attributes('value', $cell, text => $i++);
    $self->{mvc}->append_column($column);

    $self->{model} = $model;
    $self->set_model();
}

sub set_model {
    my ($self) = @_;
    $self->{model}->clear;
    print STDERR "set model $self\n";
    my ($min, $max) = $self->value_range;
    return unless (defined $min and $min ne '' and defined $max and $max ne '');
    my $delta = ($max-$min)/14;
    print STDERR "$min, $max, $delta\n";
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

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{min_hue} = 235 unless defined $self->{min_hue};
    $self->{min_hue} = $params{min_hue} if $params{min_hue};
    $self->{max_hue} = 0 unless defined $self->{max_hue};
    $self->{max_hue} = $params{max_hue} if $params{max_hue};
    $self->{hue_increment} = -1 unless defined $self->{hue_increment};
    $self->{hue_increment} = $params{hue_increment} if $params{hue_increment};
}

sub order {
    return 3;
}

sub readable_class_name {
    return 'Hue region';
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

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
}

sub supports_integer_keys {
    return 1;
}

sub has_finite_keys {
    return 1;
}

sub output_is_hue {
    return 0;
}

sub set_up_mvc {
    my ($self) = @_;
    return unless $self->{mvc};
    my $model = $self->{mvc}->get_model;
    $model->clear if $model;

    my $type = $self->key_type_for_GTK;
    $model = Gtk2::TreeStore->new("Glib::$type","Gtk2::Gdk::Pixbuf","Glib::Int","Glib::Int","Glib::Int","Glib::Int");

    $self->{mvc}->set_model($model);
    for my $col ($self->{mvc}->get_columns) {
	$self->{mvc}->remove_column($col);
    }

    my $size = $Gtk2::Ex::Geo::ColorPalette::COLOR_CELL_SIZE;
    my $i = 0;
    my $cell = Gtk2::CellRendererText->new;
    $cell->set(editable => 1);
    $cell->signal_connect(edited => \&view_changed, [$self, $i]);
    my $column = Gtk2::TreeViewColumn->new_with_attributes($self->column_header, $cell, text => $i++);
    $self->{mvc}->append_column($column);

    $cell = Gtk2::CellRendererPixbuf->new;
    $cell->set_fixed_size($size-2, $size-2);
    $column = Gtk2::TreeViewColumn->new_with_attributes('Color', $cell, pixbuf => $i++);
    $self->{mvc}->append_column($column);

    for my $c ('Red','Green','Blue','Alpha') {
	$cell = Gtk2::CellRendererText->new;
	$cell->set(editable => 1);
	$cell->signal_connect(edited => \&view_changed, [$self, $i-1]);
	$column = Gtk2::TreeViewColumn->new_with_attributes($c, $cell, text => $i++);
	$self->{mvc}->append_column($column);
    }
    $self->{mvc}->get_selection->set_mode('multiple');

    $self->{model} = $model;
    $self->set_model();
}

sub view_changed {
    my ($cell, $path, $new_value, $data) = @_;
    my ($self, $column) = @$data;
    if ($column == 0) {
        $self->key_at($path, $new_value);
    } else {
        # color changed
        my $x = $self->key_at($path);
        $column--;
        my @color = $self->color($x);
        $color[$column] = $new_value;
        print STDERR "view changed: new color @color, at path $path,$column key $x\n";
        $self->color($x, @color);
    }
    $self->set_model;
}

package Gtk2::Ex::Geo::ColorPalette::Table::Lookup;
use locale;
use Carp;

our @ISA = qw( Gtk2::Ex::Geo::ColorPalette::Table );

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{table} = {} unless defined $self->{table};
    $self->{table} = $params{table} if $params{table}; # should copy
}

sub key_type {
    my $self = shift;
    if (@_) {
        my ($type) = @_;
        croak "Unsupported key type: '$type'." unless $type eq 'Integer' or $type eq 'String';
    }
    $self->SUPER::key_type(@_);
}

sub order {
    return 4;
}

sub readable_class_name {
    return 'Color table';
}

sub supports_string_keys {
    return 1;
}

sub supports_real_keys {
    return 0;
}

sub color {
    my $self = shift;
    my $key = shift;
    if (@_ > 3) {
        $self->{table}->{$key} = [@_];
    }
    return @{$self->{table}->{$key}} if exists $self->{table}->{$key};
}

sub new_key {
    my $self = shift;
    return $self->{key_type} eq 'String' ? 'Change this.' : 0;
}

sub add_color {
    my $self = shift;
    my $key = shift;
    $self->{table}->{$key} = [@_];
}

sub remove_color {
    my $self = shift;
    my $key = shift;
    delete $self->{table}->{$key};
}

sub column_header {
    return 'Key';
}

sub key_at {
    my $self = shift;
    my $index = shift;
    my @table;
    if (@_) {
        my $new_key = shift;
        my $key = $self->key_at($index);
        my $tmp = $self->{table}->{$key};
        delete $self->{table}->{$key};
        $self->{table}->{$new_key} = $tmp;
    }
    if ($self->{key_type} eq 'String') {
        @table = sort keys %{$self->{table}};
    } else {
        @table = sort {$a <=> $b} keys %{$self->{table}};
    }
    return $table[$index];
}

sub set_model {
    my ($self) = @_;
    $self->{model}->clear;
    if ($self->{key_type} eq 'String') {
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

sub initialize {
    my $self = shift;
    $self->SUPER::initialize(@_);
    my %params = @_;
    $self->{table} = [[0,0,0,0,255],[0,255,255,255,255]] unless defined $self->{table};
    $self->{table} = $params{table} if $params{table}; # should copy
}

sub order {
    return 5;
}

sub key_type {
    my $self = shift;
    if (@_) {
        my ($type) = @_;
        croak "Unsupported key type: '$type'." unless $type eq 'Integer' or $type eq 'Real';
    }
    $self->SUPER::key_type(@_);
}

sub key_type_for_GTK {
    return 'String';
}

sub readable_class_name {
    return 'Color bins';
}

sub supports_string_keys {
    return 0;
}

sub supports_real_keys {
    return 1;
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
    my $index = $self->index($value);
    if (@_ > 3) {
        $self->{table}->[$index] = [$value, @_];
    }
    return @{$self->{table}->[$index]}[1..4];
}

sub new_key {
    return 0;
}

sub add_color {
    my $self = shift;
    my $value = shift;
    my $index = $self->index($value);
    my $table = $self->{table};
    splice @$table, $index, 0, [$value, @_];
}

sub remove_color {
    my $self = shift;
    my $value = shift;
    my $table = $self->{table};
    return if @$table == 2;
    my $index = $self->index($value);
    splice @$table, $index, 1;
}

sub column_header {
    return 'Bin';
}

sub key_at {
    my $self = shift;
    my $index = shift;
    if (@_ and $index < $#{$self->{table}}) {
        my $new_key = shift;
        $self->{table}->[$index]->[0] = $new_key;
    }
    return 'inf' if $index == $#{$self->{table}};
    return $self->{table}->[$index]->[0];
}

sub set_model {
    my ($self) = @_;
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
