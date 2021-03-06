# vim:sw=2:tabstop=2:expandtab

package Wikiprep::images;

use Wikiprep::Config;

use strict;
use Exporter 'import';
our @EXPORT_OK = qw( convertGalleryToLink convertImagemapToLink parseImageParameters );

sub convertGalleryToLink(\$) {
  my ($refToText) = @_;

  # Galleries are delimited with <gallery> tags like this:
  #
  # <gallery>
  # Image:BaseChars.png|Screenshot of Galaksija showing its base character set
  # Image:GraphicChars.png|Screenshot of Galaksija showing its pseudo-graphics character set
  # </gallery>
  #
  # Each line inside tags contains contains an image link with the same basic syntax as normal image
  # links in [[ ... ]] markup.

  1 while ( $$refToText =~ s/<gallery>
                             (.*?)
                             <\/gallery>
                            /&convertOneGallery($1)/segx
          );
}

sub convertOneGallery($) {
  my ($galleryText) = @_;

  # Take care of namespace aliases

  while(my ($key, $value) = each(%Wikiprep::Config::namespaceAliases)) {
      $galleryText =~ s/^\s*$key:/$value:/mig;
  }
  
  # Simply enclose each line that starts with Image: in [[ ... ]] and leave the links to be collected by
  # collectInternalLink()
  
  my $imageNamespace = $Wikiprep::Config::imageNamespace;

  $galleryText =~ s/^\s*($imageNamespace:.*)\s*$/[[$1]]/mig;

  return $galleryText;
}

sub convertImagemapToLink(\$) {
  my ($refToText) = @_;

  # Imagemaps are similar to galleries, except that include extra markup which must be removed.
  #
  # <imagemap>
  # Image:Sudoku dot notation.png|300px
  # # comment
  # circle  320  315 165 [[w:1|1]]
  # circle  750  315 160 [[w:2|2]]
  # circle 1175  315 160 [[w:3|3]]
  # circle  320  750 160 [[w:4|4]]
  # circle  750  750 160 [[w:5|5]]
  # circle 1175  750 160 [[w:6|6]]
  # circle  320 1175 160 [[w:7|7]]
  # circle  750 1175 160 [[w:8|8]]
  # circle 1175 1175 160 [[w:9|9]]
  # default [[w:Number|Number]]
  # </imagemap>
  
  # One line inside tags contains contains an image link with the same basic syntax as normal image
  # links in [[ ... ]] markup.
  #
  # Other lines contain location specification and a link to some other page.

  1 while ( $$refToText =~ s/<imagemap>
                             ([^<]*)      
                             <\/imagemap>
                            /&convertOneImagemap($1)/segx
          );
}

sub convertOneImagemap($) {
  my ($imagemapText) = @_;
  
  # Take care of namespace aliases

  while(my ($key, $value) = each(%Wikiprep::Config::namespaceAliases)) {
      $imagemapText =~ s/^\s*$key:/$value:/mig;
  }

  my $imageNamespace = $Wikiprep::Config::imageNamespace;

  # Convert image specification to a link
  $imagemapText =~ s/^\s*($imageNamespace:.*)\s*$/[[$1]]/mig;

  # Remove comments
  $imagemapText =~ s/^\s*#.*$//mig;

  # Remove location specifications
  $imagemapText =~ s/^.*(\[\[.*\]\])\s*$/$1/mig;

  return $imagemapText;
}

# Parse image parameters from a link to an image like this:
# [[Image:Wikipedesketch1.png|frame|right|Here is a really cool caption]]

# Note that the anchor text can be on any location, not just after the last |. This means we have to
# check all image parameters and select the one that looks the most like anchor text.

# See also http://en.wikipedia.org/wiki/Wikipedia:Extended_image_syntax

# refToImageParameters is a reference to an array that holds the string split around | symbols.
sub parseImageParameters(\@) {
  my ($refToImageParameters) = @_;

  my @candidateAnchors;

  for my $parameter (@$refToImageParameters) {
    # A list of valid parameters can be found here:
    # http://en.wikipedia.org/wiki/Wikipedia:Image_markup

    # Ignore size specifications like "250x250px" or "250px"
    # Note that MediaWiki also accepts duplicated "px"
    next if $parameter =~ /^\s*[0-9x]+px(?:px)?\s*$/i;

    # Location and type specifications
    next if $parameter =~ /^\s*(?:  left|right|center|none|
                                    thumb(?:nail)?|frame(?:less|d)?|
                                    border|
                                    baseline|middle|sub|super|text-top|text-bottom|top|bottom)\s*$/isx;

    # Link and alt specifications
    # FIXME: Would it be useful to store this link?
    next if $parameter =~ /^\s*(?:alt|link|upright|thumb(?:nail)?)=/i;

    push @candidateAnchors, $parameter;
  }

  if($#candidateAnchors >= 0) {
    # In case image has more than one valid anchor, use the longer one.
    my @sortedCandidateAnchors = sort { length($b) <=> length($a) } @candidateAnchors;
  
    return $sortedCandidateAnchors[0];
  } else {
    return "";
  }
}

1
