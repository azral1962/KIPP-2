#set text(lang: "$lang$", font: "$mainfont$", size: $fontsize$)
$if(region)$
#set text(region: "$region$")
$endif$
#show raw: set text(font: "$codefont$")
$if(mathfont)$
#show math.equation: set text(font: ($for(mathfont)$"$mathfont$",$endfor$))
$endif$
#set outline(depth: $toc-depth$)
$if(toc-title)$
#set outline(title: [$toc-title$])
$endif$
#set document(title: [$title$], author: $min-book-authors$)
#show: book.with(
  title: [$title$],
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
  authors: $min-book-authors$,
  toc: $if(toc)$true$else$false$endif$,
  $min-book-arguments$
  cfg: (
    $min-book-config-arguments$
    ..min-book-config,
  ),
  ..min-book-options,
)
