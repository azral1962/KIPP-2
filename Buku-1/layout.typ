// Judul part dan bab di tengah; section/subsection rata kiri.
#import "@preview/min-book:1.5.1": themes
#let cover-page = themes.stylish.cover-page
#let title-page = themes.stylish.title-page
#let part = themes.stylish.part
#let divider = themes.stylish.divider

#let book-headings(body) = {
  show heading: it => context {
    // Dengan parts: true, bab berada pada heading level 2.
    if it.level == 2 and it.outlined {
      pagebreak(to: "odd", weak: true)
    }
    block(width: 100%, above: 1.5em, below: 1em)[
      #align(if it.level <= 2 {center} else {left})[
        #if it.numbering != none {
          counter(heading).display(it.numbering)
          h(0.4em)
        }
        #it.body
      ]
    ]
  }
  body
}

#let styling(meta, cfg, body) = {
  cfg.numbering = (
    "{1:I}:",
    "{2:I}.",
    "{2:I}.{3:1}.",
    "{2:I}.{3:1}.{4:1}.",
    "{2:I}.{3:1}.{4:1}.{5:1}.",
    "{2:I}.{3:1}.{4:1}.{5:1}.{6:a}.",
  )
  themes.stylish.styling(meta, cfg, book-headings(body))
}
