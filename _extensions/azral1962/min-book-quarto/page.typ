// Let min-book choose margins and recto/verso layout.
#set page(paper: "$papersize$")
$if(margin)$
#set page(margin: ($for(margin/pairs)$$margin.key$: $margin.value$,$endfor$))
$endif$
