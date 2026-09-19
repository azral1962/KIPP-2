// Data contoh untuk halaman Katalog Dalam Terbitan (KDT).
#let min-book-options = (
  catalog: (
    place: "Jakarta",
    publisher: "Penerbit Contoh",
    subjects: ("Penulisan buku", "Quarto", "Typst"),
    access: ("Judul",),
    before: [
      #align(center)[*Katalog Dalam Terbitan (KDT)*]
    ],
    after: [
      #text(size: 9pt)[Data katalog ini merupakan contoh untuk demonstrasi.]
    ],
  ),
)
