package PerlSchool::Build;

use Moose;

use feature 'say';

use Template;
use Time::Piece;
use Carp;

use PerlSchool::Schema;

has tt => (
  isa        => 'Template',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_tt {
  return Template->new(
    INCLUDE_PATH => [qw(in ttlib)],
    OUTPUT_PATH  => 'docs',
    WRAPPER      => 'page.tt',
    VARIABLES    => {
      buildyear  => localtime->year,
    },
  );
}

has schema => (
  isa        => 'PerlSchool::Schema',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_schema {
  return PerlSchool::Schema->get_schema;
}

has canonical_url => (
  isa     => 'Str',
  is      => 'ro',
  default => 'https://perlschool.com/',
);

has urls => (
  isa     => 'ArrayRef',
  is      => 'rw',
  default => sub { [] },
  traits  => ['Array'],
  handles => {
    all_urls => 'elements',
    add_url  => 'push',
  },
);

has books => (
  isa        => 'ArrayRef',
  is         => 'rw',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_books => 'elements',
  },
);

sub _build_books {
  return [
    $_[0]->schema->resultset('Book')->search({
        is_perlschool_book => 1,
        is_live => 1,
      }, {
        order_by => { -desc => 'pubdate' },
      },
    )
  ];
}

has pages => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_pages => 'elements',
  },
);

has authors => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_authors => 'elements',
  },
);

sub _build_authors {
  return [
    $_[0]->schema->resultset('Author')->search(
      undef, {
        order_by => { -asc => 'sortname' },
      },
    )
  ];
}

has amazon_sites => (
  isa        => 'ArrayRef',
  is         => 'ro',
  lazy_build => 1,
  traits     => ['Array'],
  handles    => {
    all_amazon_sites => 'elements',
  },
);

sub _build_amazon_sites {
  return [
    $_[0]->schema->resultset('AmazonSite')->search(
      undef, {
        order_by => { -asc => 'sort_order' },
      },
    ),
  ];
}

sub _build_pages {
  return [qw( books about contact write )];
}

sub run {
  my $self = shift;

  $self->make_index_page;
  $self->make_book_pages;
  $self->make_authors_page;
  $self->make_other_pages;
  $self->make_sitemap;

  return;
}

sub make_index_page {
  my $self = shift;

  my @books = $self->all_books;

  $self->make_page(
    'index.html.tt', {
      feature   => $books[0],
      books     => [ @books[ 1 .. $#books ] ],
      canonical => $self->canonical_url,
    },
    'index.html',
  );

  return;
}

sub make_book_pages {
  my $self = shift;

  my @books = $self->all_books;

  for (@books) {
    $self->make_page(
      'book.html.tt', {
        feature   => $_,
        books     => \@books,
        canonical => $self->canonical_url . 'books/' . $_->slug . '/',
        amazon_sites => $self->amazon_sites,
      },
      'books/' . $_->slug . '/index.html',
    );
  }

  return;
}

sub make_authors_page {
  my $self = shift;

  $self->make_page(
    'authors.html.tt', {
      authors   => $self->authors,
      books     => $self->books,
      canonical => $self->canonical_url . 'authors/',
    },
    'authors/index.html',
  );
}

sub make_other_pages {
  my $self = shift;

  for ( $self->all_pages ) {
    $self->make_page(
      "$_.html.tt", {
        books     => $self->books,
        canonical => $self->canonical_url . "$_/",
      },
      "$_/index.html",
    );
  }

  return;
}

sub make_sitemap {
  my $self = shift;

  $self->make_page(
    'sitemap.xml.tt', {
      urls => $self->urls,
    },
    'sitemap.xml',
  );

  return;
}

sub make_page {
  my $self = shift;
  my ( $template, $vars, $output ) = @_;

  $self->tt->process( $template, $vars, $output )
    or croak $self->tt->error;

  if ( exists $vars->{canonical} ) {
    $self->add_url( $vars->{canonical} );
  }

  return;
}

1;
