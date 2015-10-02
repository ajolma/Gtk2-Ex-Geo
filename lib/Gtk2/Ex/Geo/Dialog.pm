package Gtk2::Ex::Geo::Dialog;

use strict;
use warnings;
use locale;
use Carp;
use Scalar::Util qw(blessed);
use Glib qw/TRUE FALSE/;

sub new {
    my $class = shift;
    my %params = @_;
    my $self = $params{self} ? $params{self} : {};
    bless $self => (ref($class) or $class);
    $self->initialize(@_);
    return $self;
}

sub initialize {
    my $self = shift;
    my %params = @_;
    $self->{glue} = $params{glue};
    $self->{model} = $params{model};
}

sub get_widget {
    my $self = shift;
    my $name = shift;
    my $widget = $self->{glade}->get_widget($name);
    croak "Widget '$name' not found." unless $widget;
    return $widget;
}

=pod

=head2 bootstrap($dialog_class, $title, $connects, $combos)

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

sub bootstrap {
    my($self, $name, $title, $connects, $combos) = @_;
    my $boot = 0;
    my $dialog_box;
    unless ($self->{name}) {
        $self->{name} = $name;
        $self->{glade} = $self->{glue}->get_dialog($name);
        if ($connects) {
            for my $n (keys %$connects) {
                my $w = $self->get_widget($n);
                $w->signal_connect(@{$connects->{$n}}) if defined $w;
            }
        }
        if ($combos) {
            for my $n (@$combos) {
                my $combo = $self->get_widget($n);
                next unless defined $combo;
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
        $dialog_box = $self->get_widget($name);
        $dialog_box->set_position('center');
    } else {
        $dialog_box = $self->get_widget($name);
        $dialog_box->move(@{$self->{position}}) unless $dialog_box->get('visible');
    }
    $dialog_box->set_title($title);
    $dialog_box->show_all;
    $dialog_box->present;
    return $boot;
}

=pod

=head2 hide_dialog($dialog_class)

Hides the given dialog of this layer object.

=cut

sub hide {
    my($self, $dialog) = @_;
    $self->{position} = [$self->get_widget($self->{name})->get_position];
    $self->get_widget($self->{name})->hide();
}

sub visible {
    my($self, $dialog) = @_;
    return $self->get_widget($self->{name})->get('visible');
}

sub apply {
    my ($self, $close) = @{$_[1]};
    $self->hide if $close;
    $self->{glue}->{overlay}->render;
}

sub cancel {
    my $self;
    if (@_ == 2) {
        (undef, $self) = @_;
    } elsif (@_ == 3) {
        (undef, undef, $self) = @_;
    }
    $self->{model}->clone($self->{model_backup});
    $self->hide;
    $self->{glue}->{overlay}->render;
    return 1;
}

sub progress {
    my($progress, $msg, $bar) = @_;
    $progress = 1 if $progress > 1;
    $bar->set_fraction($progress);
    Gtk2->main_iteration while Gtk2->events_pending;
    return 1;
}

sub setup_combo {
    my ($self, $name) = @_;
    my $combo = $self->get_widget($name);
    next unless defined $combo;
    unless ($combo->isa('Gtk2::ComboBoxEntry')) {
        my $renderer = Gtk2::CellRendererText->new;
        $combo->pack_start($renderer, TRUE);
        $combo->add_attribute($renderer, text => 0);
    }
    my $model = Gtk2::ListStore->new('Glib::String');
    $combo->set_model($model);
    $combo->set_text_column(0) if $combo->isa('Gtk2::ComboBoxEntry');
}

sub refill_combo {
    my ($self, $name, $entry_list, $selected) = @_;
    my $combo = $self->get_widget($name);
    my $model = $combo->get_model;
    $model->clear;
    my $i = 0;
    my $active;
    for my $entry (@$entry_list) {
	$model->set($model->append, 0, $entry);
	$active = $i if defined $selected && $entry eq $selected;
	$i++;
    }
    $active = 0 unless defined $active;
    $combo->set_active($active);
}

sub get_value_from_combo {
    my($self, $combo) = @_;
    $combo = blessed $combo ? $combo : $self->get_widget($combo);
    croak "Can't find combobox $combo." unless $combo;
    my $model = $combo->get_model;
    croak "Uninitialized combobox $combo." unless $model;
    my $a = $combo->get_active();
    if ($a == -1) { # comboboxentry
        if ($combo->isa('Gtk2::ComboBoxEntry')) {
            return $combo->child->get_text;
        } else {
            return; # croak "Can't get value from combobox entry $combo.";
        }
    }
    my $iter = $model->get_iter_from_string($a);
    croak "Can't convert $a to iter in combobox $combo." unless $iter;
    return $model->get_value($iter);
}

sub get_selected_from_selection {
    my $selection = shift;
    my @sel = $selection->get_selected_rows;
    my %sel;
    for (@sel) {
	$sel{$_->to_string} = 1;
    }
    my $model = $selection->get_tree_view->get_model;
    my $iter = $model->get_iter_first();
    my $i = 0;
    my %s;
    while ($iter) {
	my($id) = $model->get($iter, 0);
	$s{$id} = 1 if $sel{$i++};
	$iter = $model->iter_next($iter);
    }
    return \%s;
}

1;
