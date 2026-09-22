// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))


#import "@preview/min-book:1.5.1": book, themes, appendices, annexes, note, blockquote, comment, mark, event, scene

// Advanced users may replace these dictionaries through include-in-header.
#let min-book-config = (:)
#let min-book-options = (:)
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
#import "layout.typ" as example-theme
#let min-book-config = (theme: example-theme)
#set bibliography(title: none)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

// Let min-book choose margins and recto/verso layout.
#set page(paper: "iso-b5")

#set text(lang: "id", font: "Libertinus Serif", size: 12pt)
#show raw: set text(font: "DejaVu Sans Mono")
#set outline(depth: 3)
#set outline(title: [Daftar Isi])
#set document(title: [Prinsip-Prinsip Komunikasi], author: ("Armein Z. R. Langi",))
#show: book.with(
  title: [Prinsip-Prinsip Komunikasi],
  subtitle: [Membangun Relasi, Kepercayaan, dan Nilai di Era Kecerdasan Buatan],
  authors: ("Armein Z. R. Langi",),
  toc: true,
  part: auto,
    date: datetime(year: 2026, month: 9, day: 19),
  cfg: (
    theme: themes.elegance,
        two-sided: true,
        paper-friendly: false,
        cover: (back: false,),
    ..min-book-config,
  ),
  ..min-book-options,
)
// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 2, numbering: none)[Komunikasi Interpersonal dan Publik]
<komunikasi-interpersonal-dan-publik>
#quote(block: true)[
#strong[Komunikasi bukan sekadar kemampuan menyampaikan pesan. Komunikasi adalah kemampuan mengenali manusia, membangun kepercayaan, menciptakan nilai bersama, dan merawat relasi yang membuat kita dapat bertumbuh.]
]

Buku ini mengajak Anda menjalani sebuah petualangan belajar: dari percakapan dengan diri sendiri, menuju keluarga dan sahabat, dunia profesional, komunitas, ruang publik, serta komunikasi berbantuan kecerdasan buatan. Harta karun yang kita cari bukanlah kepandaian berbicara semata, melainkan kemampuan untuk memahami, bersepakat, bertindak, dan tetap memiliki ruang untuk berelasi kembali.

#heading(level: 2, numbering: none)[Dedikasi]
<dedikasi>
#block[
Untuk para mahasiswa yang bersedia hadir setiap minggu---

yang datang dengan rasa ingin tahu,

yang berani mencoba meskipun belum yakin,

yang bersedia mendengarkan ketika lebih mudah berbicara,

yang mau mengakui kesalahan, memperbaiki diri, dan mencoba kembali.

Kerja keras untuk menghasilkan produk, layanan, dan karya yang menarik sungguh berharga. Namun, investasi untuk membangun diri menjadi pribadi yang tulus, cakap, dapat dipercaya, dan menarik untuk diajak bertumbuh bersama akan memperkaya seluruh kehidupan.

Semoga buku ini menemani Anda menemukan kekayaan itu.

]
#heading(level: 2, numbering: none)[Kata Pengantar]
<kata-pengantar>
Ada satu pertanyaan sederhana yang terus menyertai saya sebagai dosen: mengapa seseorang yang memiliki pengetahuan dan kemampuan teknis yang baik belum tentu berhasil menyampaikan gagasannya, memperoleh kepercayaan, atau membangun kerja sama dengan orang lain? Jawabannya membawa saya pada keyakinan yang menjadi dasar buku ini: kehidupan bertumbuh melalui relasi, dan relasi dibangun melalui komunikasi.

Komunikasi bukan sekadar kegiatan memindahkan informasi dari seorang pengirim kepada penerima. Komunikasi adalah perjumpaan antarmanusia. Di dalamnya ada kebutuhan untuk dipahami, keberanian untuk menyatakan diri, kesediaan untuk mendengarkan, dan tanggung jawab untuk memperlakukan orang lain sebagai pribadi yang bernilai. Dalam semangat pemikiran Peter Drucker, keberhasilan profesional pada akhirnya tidak dapat dilepaskan dari kemampuan memahami orang yang kita layani dan menciptakan nilai bersama mereka. Hal yang sama berlaku dalam kehidupan personal: kepercayaan, persahabatan, kasih, dan kerja sama tidak hadir dengan sendirinya. Semuanya perlu dirawat melalui komunikasi yang jujur, tepat, dan penuh empati.

Saya tidak sampai pada keyakinan itu hanya melalui ruang kuliah atau buku-buku teori. Sebagian pemahaman tersebut tumbuh dari perjalanan hidup saya sendiri. Pada 1970, ketika masih duduk di kelas dua sekolah dasar di Tomohon, Sulawesi Utara, saya menerima kartu-kartu pos dari ayah saya yang sedang bertugas belajar di dekat San Francisco. Melalui gambar Golden Gate dan cerita tentang negeri yang jauh, lahirlah sebuah impian sederhana: suatu hari saya ingin belajar dan mengalami kehidupan di luar negeri.

Perjalanan menuju impian itu tidak berlangsung lurus. Setelah lulus dari Teknik Elektro ITB pada 1987, saya memilih menjadi dosen dan kemudian bergabung dengan PAU Mikroelektronika. Ketika kesempatan studi lanjut mulai terbuka, kemampuan bahasa Inggris saya justru menjadi hambatan. Saya memasuki program persiapan dengan nilai TOEFL terendah dan nyaris tidak diterima. Namun, melalui latihan yang tekun, saya akhirnya meraih nilai tertinggi dan dipercaya menyampaikan pidato penutupan mewakili peserta dari seluruh Indonesia. Sesudah itu pun jalan belum segera terbuka. Tujuh surat penolakan datang sebelum satu surat penerimaan dari University of Manitoba akhirnya tiba.

Pengalaman tersebut mengajarkan kepada saya bahwa komunikasi bukan bakat yang dibagikan hanya kepada orang-orang tertentu. Ia adalah kompetensi yang dapat dipelajari, dilatih, diperbaiki, dan ditumbuhkan. Saya juga belajar bahwa pencapaian tidak pernah berdiri sendiri. Di balik satu keberhasilan selalu ada orang-orang yang percaya, mendampingi, membuka jalan, dan memberi alasan untuk bertahan. Bahkan ketika kesempatan studi itu datang, saya memilih menunda keberangkatan agar dapat mendampingi istri saya, Ina, menyambut kelahiran putri kami, Gladys. Impian dapat menunggu; relasi yang berharga perlu dihadiri.

Karena itu, buku ini saya tulis terutama untuk Anda, para mahasiswa yang hadir setiap minggu dengan keadaan yang mungkin tidak selalu mudah. Saya memahami bahwa sebagian dari Anda mungkin merasa canggung memulai percakapan, takut salah ketika berbicara di depan orang lain, kesulitan menyampaikan ketidaksetujuan, atau bingung menghadapi orang yang memiliki kepentingan berbeda. Ada pula yang sangat menguasai bidangnya, tetapi belum menemukan bahasa yang membuat orang lain mau mendengarkan. Pergumulan seperti itu wajar. Anda tidak sedang sendirian, dan Anda tidak harus menjadi pribadi lain untuk dapat berkomunikasi dengan baik.

Yang perlu Anda kembangkan bukan sekadar kefasihan berbicara, melainkan kemampuan mengenali diri, memahami orang lain, memilih peran dan bahasa yang sesuai, mendengarkan tanggapan, serta mengarahkan percakapan menuju pengertian, kesepakatan, tindakan, dan relasi yang tetap sehat. Dalam dunia profesional, kemampuan ini membantu Anda bekerja dalam tim, memimpin, bernegosiasi, melayani pelanggan, dan menjelaskan gagasan kepada publik. Dalam kehidupan personal, kemampuan yang sama menolong Anda membangun persahabatan, merawat keluarga, memperbaiki kesalahpahaman, dan hadir secara utuh bagi orang lain.

Ketika kecerdasan buatan semakin mampu membantu kita menyusun, menerjemahkan, dan menyesuaikan pesan, buku ini tetap menempatkan manusia dan relasi sebagai pusat komunikasi. Teknologi dapat menjadi cermin, pelatih, dan pendamping, tetapi tanggung jawab untuk memahami, memilih, serta merawat kepercayaan tetap berada pada diri kita.

Inilah "harta karun" yang ingin saya bagikan melalui buku ini. Harta itu bukan sekumpulan kalimat ajaib untuk memengaruhi orang, apalagi cara memanipulasi mereka. Harta itu adalah kecakapan membangun relasi yang dilandasi ketulusan, kepercayaan, empati, dan penciptaan nilai bersama. Ketika Anda mampu mendengarkan dengan sungguh-sungguh, menceritakan pengalaman dengan bermakna, menemukan kisah inspiratif di balik fakta, menjelaskan konsep dengan jernih, menyampaikan pendapat dengan bertanggung jawab, dan mengajak orang lain bertindak tanpa merendahkan kebebasannya, Anda sedang memiliki kekayaan yang akan menyertai kehidupan pribadi dan karier Anda dalam jangka panjang.

Buku ini dirancang sebagai sebuah petualangan belajar. Setiap bagian akan membantu Anda menentukan tujuan, memberi perhatian pada persoalan yang nyata, memahami mengapa suatu keterampilan penting, mencoba cara yang dapat dilakukan, lalu menunjukkan kemampuan tersebut dalam tindakan. Kerangka 4P---Persiapan, Presentasi, Praktis, dan #emph[Perform] (Unjuk Kerja)---serta rute TAIDA---#emph[Target, Attention, Interest, Desire,] dan #emph[Action]---digunakan agar pembelajaran tidak berhenti pada pengetahuan. Anda akan diajak berlatih, mengamati respons, melakukan refleksi, memperbaiki pendekatan, dan mencoba kembali. Teori memberi peta, tetapi latihanlah yang membuat jalan itu sungguh-sungguh Anda kenal.

Dalam petualangan ini, saya tidak ingin berdiri sebagai orang yang sekadar memberi petunjuk dari kejauhan. Saya ingin berjalan bersama Anda sebagai pendidik dan sesama pembelajar---seseorang yang pernah merasa kurang siap, pernah ditolak, pernah harus mengubah cara belajar, dan terus menemukan bahwa pertumbuhan selalu mungkin. Saya berharap ruang kelas hadir di benak Anda ketika membaca halaman-halaman buku ini: ada pertanyaan yang boleh diajukan, kesalahan yang boleh diperbaiki, dan keberhasilan kecil yang layak dirayakan.

Pada akhirnya, ukuran keberhasilan belajar komunikasi bukanlah seberapa banyak istilah yang dapat Anda hafalkan atau seberapa mengesankan Anda tampak di hadapan orang lain. Ukurannya ialah apakah kehadiran Anda membuat orang lain merasa lebih dipahami; apakah gagasan dapat dijelaskan dengan jernih; apakah perbedaan dapat dikelola dengan hormat; apakah kesepakatan dapat diwujudkan menjadi tindakan; dan apakah sesudah percakapan berakhir, relasi masih memiliki ruang untuk bertumbuh.

Selamat memulai perjalanan ini. Bawalah rasa ingin tahu, keberanian untuk mencoba, kerendahan hati untuk mendengarkan, dan kepedulian kepada sesama. Semoga buku ini menolong Anda menemukan dan mengembangkan daya tarik yang paling bernilai: bukan sekadar penampilan yang memikat perhatian, melainkan karakter dan cara berkomunikasi yang membuat orang lain merasa dihargai, dipercaya, dan diajak bertumbuh bersama.

Bandung, Agustus 2026

#strong[Armein Z. R. Langi]

#heading(level: 2, numbering: none)[Cara Menggunakan Buku Ini]
<cara-menggunakan-buku-ini>
Buku ini tidak dirancang untuk sekadar ditamatkan. Ia dirancang untuk #strong[dialami]. Anda akan membaca konsep, mengingat pengalaman, mencoba percakapan, memperhatikan respons, menerima umpan balik, lalu memperbaiki cara berkomunikasi. Karena itu, keberhasilan Anda tidak terutama ditentukan oleh seberapa cepat halaman-halaman ini selesai dibaca, tetapi oleh seberapa sungguh-sungguh Anda mengubah pengetahuan menjadi kebiasaan dan tindakan.

Saya berharap Anda membaca buku ini seperti sedang berada di ruang kelas bersama saya. Berhentilah ketika sebuah pertanyaan menyentuh pengalaman Anda. Tuliskan jawaban yang jujur. Cobalah latihan meskipun hasil pertama belum baik. Komunikasi adalah kompetensi yang bertumbuh melalui praktik; kecanggungan pada awal perjalanan bukan tanda bahwa Anda tidak berbakat, melainkan tanda bahwa Anda sedang belajar sesuatu yang baru.

#heading(level: 3, numbering: none)[Satu Bab, Lima Langkah]
<satu-bab-lima-langkah>
Setiap bab menggunakan pola #strong[4P + Refleksi]. Pola ini sengaja dibuat konsisten agar energi Anda digunakan untuk belajar, bukan untuk menebak-nebak apa yang harus dilakukan.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Tahap], [Apa yang Anda lakukan], [Pertanyaan pemandu],),
  table.hline(),
  [#strong[Persiapan]], [Menghubungkan topik dengan pengalaman dan kebutuhan Anda], [Harta karun apa yang perlu saya peroleh, dan mengapa hal ini penting bagi hidup saya?],
  [#strong[Presentasi]], [Memahami konsep melalui cerita, teori, contoh, dan demonstrasi], [Apa yang sedang terjadi, mengapa hal itu penting, dan bagaimana cara kerjanya?],
  [#strong[Praktis]], [Mencoba keterampilan dalam latihan yang aman dan terjangkau], [Dapatkah saya melakukannya dengan bimbingan dan umpan balik?],
  [#strong[Unjuk Kerja (#emph[Perform])]], [Memperlihatkan kompetensi dalam situasi nyata atau simulasi], [Dapatkah komunikasi saya menghasilkan perubahan yang bertanggung jawab?],
  [#strong[Refleksi]], [Membaca respons, hasil, dan dampaknya terhadap relasi], [Apa yang berhasil, apa yang perlu diperbaiki, dan apa yang akan saya lakukan berikutnya?],
)
Teori memberi Anda peta. Praktik membuat Anda mengenali jalan. Unjuk kerja menunjukkan bahwa Anda dapat menempuhnya. Refleksi membantu Anda menempuh jalan berikutnya dengan lebih baik.

#heading(level: 3, numbering: none)[Kenali Penanda Perjalanan]
<kenali-penanda-perjalanan>
Di sepanjang buku, Anda akan menemukan beberapa unsur yang berulang.

#heading(level: 4, numbering: none)[Target Harta Karun]
<target-harta-karun>
Bagian ini menjelaskan kompetensi yang akan Anda miliki setelah mempelajari sebuah bab. Bacalah terlebih dahulu agar Anda mengetahui tujuan perjalanan, ukuran keberhasilan, dan manfaatnya bagi kehidupan personal maupun profesional.

#heading(level: 4, numbering: none)[Catatan dari Perjalanan Saya]
<catatan-dari-perjalanan-saya>
Di bagian ini saya membagikan pengalaman yang membentuk cara saya memahami komunikasi: impian masa kecil di Tomohon, masa belajar di ITB, pergumulan bahasa Inggris, surat-surat penolakan, dukungan orang-orang yang membuka jalan, pilihan mendahulukan keluarga, dan pengalaman belajar di luar negeri. Kisah tersebut tidak dimaksudkan sebagai resep yang harus Anda tiru. Gunakanlah sebagai teman berpikir: apa yang serupa, apa yang berbeda, dan pelajaran apa yang dapat Anda bawa ke perjalanan Anda sendiri?

#heading(level: 4, numbering: none)[Peta Konsep]
<peta-konsep>
Peta konsep merangkum hubungan antargagasan. Jangan hanya menghafal istilahnya. Cobalah menjelaskan kembali hubungan tersebut dengan bahasa Anda sendiri dan gunakan satu contoh dari kehidupan nyata.

#heading(level: 4, numbering: none)[Jeda Refleksi]
<jeda-refleksi>
Ketika menemukan bagian ini, berhentilah sejenak. Tulis jawaban sebelum membaca lebih jauh. Jawaban yang jujur lebih berguna daripada jawaban yang terdengar paling akademik.

#heading(level: 4, numbering: none)[Latihan]
<latihan>
Latihan adalah ruang yang aman untuk salah. Anda boleh berhenti, bertanya, mencoba cara lain, dan mengulang. Kerjakan bersama rekan bila diminta, sebab komunikasi tidak dapat dipelajari sepenuhnya sendirian.

#heading(level: 4, numbering: none)[Tantangan Unjuk Kerja]
<tantangan-unjuk-kerja>
Pada tahap ini Anda diminta memperlihatkan kemampuan dalam percakapan, presentasi, negosiasi, tulisan, atau simulasi. Yang dinilai bukan apakah Anda tampak seperti pembicara profesional, melainkan apakah komunikasi Anda sesuai dengan person, tujuan, konteks, dan relasi.

#heading(level: 4, numbering: none)[Ringkasan Satu Menit]
<ringkasan-satu-menit>
Gunakan ringkasan ini untuk memeriksa pemahaman. Setelah membacanya, tutup buku dan jelaskan kembali gagasan utama dengan kata-kata Anda sendiri.

#heading(level: 3, numbering: none)[Gunakan TAIDA sebagai Kompas]
<gunakan-taida-sebagai-kompas>
Di banyak bagian buku, Anda akan menggunakan rute #strong[TAIDA]:

#quote(block: true)[
#strong[Target → Attention → Interest → Desire → Action]
]

TAIDA membantu Anda membaca keadaan komunikasi.

- #strong[Target:] Siapa person yang perlu saya pahami dan ajak berkomunikasi?
- #strong[Attention:] Apakah ia melihat masalah atau peluang yang relevan?
- #strong[Interest:] Apakah ia melihat bahwa ada kemungkinan solusi yang layak dipahami?
- #strong[Desire:] Apakah ia menginginkan manfaat atau hasil yang ditawarkan?
- #strong[Action:] Apakah kami dapat mencapai kesepakatan dan menentukan langkah yang dapat dilakukan?

Rute ini bukan tangga yang harus selalu dinaiki secara lurus. Person dapat ragu, mundur, berubah pikiran, atau menolak. Respons mereka bukan gangguan terhadap rencana Anda; respons adalah informasi yang membantu Anda menyesuaikan komunikasi. Tujuannya bukan memaksa orang tiba di tahap Action, melainkan membantu semua pihak memahami keadaan dan membuat pilihan yang bertanggung jawab.

#heading(level: 3, numbering: none)[Bawa Pengalaman Nyata]
<bawa-pengalaman-nyata>
Sebelum membaca sebuah bab, ingatlah satu pengalaman yang relevan: percakapan yang tidak berjalan baik, tugas kelompok yang membingungkan, gagasan yang sulit dijelaskan, kesalahpahaman dengan teman, atau situasi ketika Anda tidak tahu harus berkata apa. Pengalaman itu akan menjadi bahan belajar yang lebih hidup daripada contoh yang sepenuhnya asing.

Anda tidak perlu membagikan pengalaman yang terlalu pribadi. Pilihlah kasus yang aman untuk dibahas. Hormati privasi orang lain dengan menyamarkan nama dan informasi yang dapat mengungkap identitas mereka.

#heading(level: 3, numbering: none)[Bangun Portofolio, Bukan Sekadar Kumpulan Tugas]
<bangun-portofolio-bukan-sekadar-kumpulan-tugas>
Simpan bukti perkembangan Anda: rencana, catatan percakapan, rekaman yang dibuat dengan persetujuan, umpan balik, versi perbaikan, kesepakatan, dan refleksi. Gunakan siklus berikut:

#quote(block: true)[
#strong[Rencanakan → Komunikasikan → Amati → Refleksikan → Perbaiki]
]

Portofolio yang baik tidak hanya berisi hasil terbaik. Ia juga memperlihatkan perubahan dari percobaan pertama menuju percobaan berikutnya. Kesalahan yang dianalisis dengan jujur dapat menjadi bukti belajar yang lebih kuat daripada penampilan yang tampak lancar tetapi tidak menghasilkan pemahaman.

#heading(level: 3, numbering: none)[Gunakan AI dengan Tetap Menjadi Pemilik Komunikasi]
<gunakan-ai-dengan-tetap-menjadi-pemilik-komunikasi>
Kecerdasan buatan dapat membantu Anda menyiapkan pertanyaan, mencoba beberapa pilihan bahasa, berlatih menghadapi keberatan, meringkas percakapan, atau meninjau nada sebuah pesan. Namun, AI tidak mengenal seseorang secara utuh dan tidak menanggung akibat relasi dari pesan yang dikirimkan.

Karena itu, pegang lima aturan berikut:

+ Jangan memasukkan informasi pribadi atau rahasia tanpa dasar yang sah dan persetujuan yang tepat.
+ Periksa fakta, asumsi, bias, dan nada setiap keluaran AI.
+ Nyatakan penggunaan AI apabila konteks akademik atau profesional menuntut transparansi.
+ Jangan menyerahkan permintaan maaf, konflik personal, keputusan nilai, atau komunikasi berisiko tinggi sepenuhnya kepada AI.
+ Pertahankan suara, penilaian, dan tanggung jawab Anda sebagai manusia.

Gunakan AI untuk meningkatkan kompetensi manusia, bukan untuk menghindari proses belajar atau mengambil alih relasi.

#heading(level: 3, numbering: none)[Ukuran Keberhasilan Anda]
<ukuran-keberhasilan-anda>
Pada akhir setiap latihan atau unjuk kerja, jangan hanya bertanya, "Apakah pesan saya sudah terkirim?" Tanyakan pula:

- Apakah saya memahami person yang saya hadapi?
- Apakah tujuan saya jelas dan bertanggung jawab?
- Apakah bahasa serta cara yang saya pilih sesuai?
- Apakah saya sungguh mendengarkan respons?
- Apakah tercapai pengertian, kesepakatan, atau langkah berikutnya yang cukup jelas?
- Bagaimana keadaan relasi setelah komunikasi berlangsung?

Ukuran akhir buku ini sederhana, tetapi menuntut latihan yang sungguh-sungguh:

#quote(block: true)[
#strong[Komunikasi yang efektif menghasilkan tindakan yang bertanggung jawab sekaligus menjaga relasi tetap sehat.]
]

Anda tidak perlu menjadi orang lain untuk berhasil. Datanglah sebagai diri Anda, bawalah rasa ingin tahu, dan izinkan setiap latihan memperluas repertoar Anda sedikit demi sedikit. Saya akan menemani Anda melalui halaman-halaman berikutnya.

#heading(level: 2, numbering: none)[Peta Petualangan Belajar]
<peta-petualangan-belajar>
Setiap petualangan memerlukan peta. Peta tidak menggantikan perjalanan, tetapi membantu kita memahami arah, mengenali tahap yang sedang ditempuh, dan tidak kehilangan tujuan ketika jalan terasa sulit.

Perjalanan dalam buku ini bergerak dari lingkar kehidupan yang paling dekat menuju lingkar yang semakin luas:

#quote(block: true)[
#strong[Saya → Keluarga dan Sahabat → Rekan Kerja dan Pelanggan → Komunitas → Dunia]
]

Kita memulai dari diri sendiri karena setiap komunikasi lahir dari cara kita memaknai peristiwa. Kita kemudian belajar hadir bagi orang-orang terdekat, bekerja dan menciptakan nilai bersama, hidup di tengah perbedaan, serta menyampaikan gagasan kepada publik. Pada setiap tahap, kecerdasan buatan dipelajari sebagai alat bantu yang harus tetap berada di bawah penilaian dan tanggung jawab manusia.

#heading(level: 3, numbering: none)[Empat Wilayah Perjalanan]
<empat-wilayah-perjalanan>
#heading(level: 4, numbering: none)[Bagian I --- Menemukan Diri dan Menjumpai Orang Lain]
<bagian-i-menemukan-diri-dan-menjumpai-orang-lain>
Di wilayah pertama, Anda belajar bahwa komunikasi dimulai dari pribadi (#emph[person]), bukan dari pesan. Anda akan mengenali kecenderungan diri, memilih peran naratif (#emph[character]) yang sesuai, mendengarkan orang lain, merawat relasi dekat, dan menemukan bahasa yang dapat menjembatani makna.

#strong[Harta karun:] kesadaran diri, empati, kemampuan mendengarkan, komunikasi asertif, dan keluwesan bahasa.

#heading(level: 4, numbering: none)[Bagian II --- Mengubah Komunikasi Menjadi Nilai dan Tindakan]
<bagian-ii-mengubah-komunikasi-menjadi-nilai-dan-tindakan>
Di wilayah kedua, Anda memasuki kehidupan profesional. Anda belajar menemukan kebutuhan, memperoleh perhatian secara layak, menumbuhkan minat, menjelaskan manfaat, mencapai kesepakatan, serta bernegosiasi dengan beberapa pihak.

#strong[Harta karun:] kemampuan menciptakan nilai bersama dan mengubah percakapan menjadi tindakan yang dapat dipertanggungjawabkan.

#heading(level: 4, numbering: none)[Bagian III --- Memperluas Lingkar Relasi]
<bagian-iii-memperluas-lingkar-relasi>
Di wilayah ketiga, Anda berhadapan dengan orang-orang yang mungkin tidak memiliki pengalaman, kepentingan, atau nilai yang sama. Anda belajar berkomunikasi dalam komunitas, berbicara kepada publik, dan menggunakan AI tanpa kehilangan keaslian maupun tanggung jawab.

#strong[Harta karun:] kemampuan hidup di tengah perbedaan, membangun tindakan kolektif, serta memberi kontribusi kepada dunia.

#heading(level: 4, numbering: none)[Bagian IV --- Memiliki Harta Karun Itu]
<bagian-iv-memiliki-harta-karun-itu>
Wilayah terakhir bukan tempat untuk menambah banyak istilah baru. Di sini Anda mengintegrasikan seluruh kompetensi dalam sebuah proyek puncak (#emph[capstone]). Anda memperlihatkan bahwa Anda dapat mengenali pribadi, memilih peran naratif, menetapkan tujuan, membaca keadaan TAIDA, memilih repertoar dan bahasa, menggunakan AI secara tepat, mencapai hasil, serta menilai dampaknya terhadap relasi.

#strong[Harta karun:] kemampuan menjadi komunikator yang utuh, adaptif, etis, dan berpusat pada manusia.

#heading(level: 3, numbering: none)[Peta Lima Belas Bab]
<peta-lima-belas-bab>
#table(
  columns: (30.77%, 23.08%, 23.08%, 23.08%),
  align: (right,auto,auto,auto,),
  table.header([Bab], [Pertanyaan perjalanan], [Harta karun], [Bukti bahwa Anda telah menemukannya],),
  table.hline(),
  [#strong[1]], [Siapa yang sebenarnya berkomunikasi?], [Memahami pribadi, kepribadian, dan peran naratif], [#emph[Personal Communication Character Map]],
  [#strong[2]], [Bagaimana saya berkomunikasi dengan diri sendiri?], [Memisahkan fakta, interpretasi, dan narasi diri], [#emph[Intra-Self Communication Journal]],
  [#strong[3]], [Bagaimana relasi dekat diperoleh, dirawat, dan diperbaiki?], [Mendengarkan, menyatakan diri, dan memperbaiki relasi], [#emph[Relationship Repair Conversation]],
  [#strong[4]], [Bahasa apa yang sesuai bagi pribadi dan situasi ini?], [Menjelaskan satu makna melalui beberapa bahasa], [#emph[Five-Language Translation Portfolio]],
  [#strong[5]], [Mengapa para profesional berkomunikasi?], [Menemukan kebutuhan dan menciptakan nilai bersama], [#emph[Customer Problem Statement]],
  [#strong[6]], [Dengan siapa saya perlu berbicara dan bagaimana memperoleh perhatian?], [Mengenali target dan membangun relevansi], [#emph[Target--Attention Pitch]],
  [#strong[7]], [Mengapa person perlu memedulikan solusi ini?], [Menghubungkan masalah dengan kemungkinan solusi], [#emph[Problem--Solution Pitch]],
  [#strong[8]], [Apakah komunikasi saya sungguh bekerja?], [Mengintegrasikan Target, Attention, dan Interest], [Laboratorium Kinerja UTS],
  [#strong[9]], [Bagaimana minat berubah menjadi keinginan yang sadar?], [Menjelaskan manfaat, bukti, cara kerja, dan risiko], [#emph[Desire-Building Demonstration]],
  [#strong[10]], [Bagaimana keinginan berubah menjadi langkah nyata?], [Mencapai kesepakatan yang jelas dan layak], [#emph[Agreement Document]],
  [#strong[11]], [Bagaimana pihak yang berbeda menemukan wilayah kesepakatan?], [Membedakan posisi, kepentingan, dan kendala], [#emph[Negotiated Agreement + Reflection]],
  [#strong[12]], [Bagaimana kita bertindak bersama di tengah perbedaan?], [Mediasi dan kesepakatan komunitas], [#emph[Community Agreement]],
  [#strong[13]], [Bagaimana satu gagasan berbicara kepada dunia?], [Komunikasi publik yang jelas, menarik, dan bertanggung jawab], [#emph[One Idea, Four Public Languages]],
  [#strong[14]], [Bagaimana AI membantu tanpa mengambil alih kemanusiaan?], [Memilih peran, data, kewenangan, dan batas AI], [Spesifikasi Kopilot Komunikasi],
  [#strong[15]], [Dapatkah saya mengintegrasikan seluruh kompetensi?], [Komunikasi efektif, adaptif, etis, dan relasional], [Proyek puncak dan portofolio akhir],
)
#heading(level: 3, numbering: none)[Rute TAIDA di Sepanjang Peta]
<rute-taida-di-sepanjang-peta>
TAIDA adalah kompas yang digunakan berulang kali:

#quote(block: true)[
#strong[Target → Attention → Interest → Desire → Action]
]

Kompas ini membantu Anda bertanya: siapa person-nya, apa yang sedang ia pahami atau rasakan, perubahan apa yang layak dicapai, serta komunikasi apa yang diperlukan sekarang? TAIDA tidak digunakan untuk memperlakukan manusia seperti mesin yang harus digerakkan. Ia digunakan untuk membuat komunikator lebih peka terhadap keadaan orang lain dan lebih bertanggung jawab ketika mengajak mereka melangkah.

#heading(level: 3, numbering: none)[Jejak Perjalanan Penulis]
<jejak-perjalanan-penulis>
Saya pun tidak memperoleh seluruh harta karun ini sekaligus. Perjalanan saya dimulai dari seorang anak di Tomohon yang memandang gambar Golden Gate pada kartu pos ayahnya. Bertahun-tahun kemudian, saya lulus dari Teknik Elektro ITB, menjadi dosen, belajar di PAU Mikroelektronika, mengikuti pelatihan bahasa Inggris, menerima tujuh surat penolakan, dan akhirnya memperoleh kesempatan studi di Kanada.

Di tengah perjalanan itu, saya belajar bahwa ketekunan perlu disertai kerendahan hati untuk belajar; bahwa kesempatan sering datang melalui kepercayaan dan pertolongan orang lain; serta bahwa impian tidak boleh membuat kita melupakan orang yang perlu kita dampingi. Saya pernah menunda keberangkatan untuk berada di sisi Ina ketika Gladys akan lahir. Pada 13 Desember 1989, ketika lampu-lampu Los Angeles terlihat dari jendela pesawat, saya memahami bahwa kenyataan dapat menjadi lebih indah daripada impian. Tujuh tahun kemudian, saya kembali bersama Ina, Gladys, Kezia, dan Andria. Perjalanan itu tidak lagi hanya tentang tempat yang ingin saya capai, tetapi tentang orang-orang yang membuat perjalanan tersebut bermakna.

Kisah Anda tentu berbeda. Anda tidak perlu pergi ke tempat yang sama atau menghadapi tantangan yang sama. Namun, Anda juga memiliki pengalaman, relasi, kegagalan, pertanyaan, dan impian yang dapat diolah menjadi sumber belajar. Buku ini mengundang Anda menemukan maknanya.

#heading(level: 3, numbering: none)[Bekal yang Perlu Anda Bawa]
<bekal-yang-perlu-anda-bawa>
- #strong[Rasa ingin tahu], agar Anda sungguh tertarik kepada orang lain.
- #strong[Kejernihan], agar makna tidak tenggelam dalam banyaknya kata.
- #strong[Kerendahan hati], agar Anda bersedia mengakui bahwa pembacaan Anda dapat keliru.
- #strong[Keberanian], agar percakapan penting tidak terus ditunda.
- #strong[Kepedulian], agar keberhasilan tidak dibeli dengan rusaknya martabat atau relasi.
- #strong[Akuntabilitas], agar Anda bertanggung jawab atas pesan, pilihan, dan penggunaan teknologi.

#heading(level: 3, numbering: none)[Tanda Bahwa Anda Telah Sampai]
<tanda-bahwa-anda-telah-sampai>
Anda tidak perlu menjadi pembicara paling fasih di ruangan. Anda telah bergerak jauh ketika mampu mengenali siapa yang dihadapi, mendengarkan sebelum menyimpulkan, memilih bahasa yang dapat dipahami, menyesuaikan diri berdasarkan respons, mencapai kesepakatan yang layak, dan menjaga relasi tetap memiliki masa depan.

#quote(block: true)[
#strong[Komunikasi yang efektif = tindakan yang berhasil + relasi yang sehat + tanggung jawab yang terpelihara.]
]

Sekarang peta telah terbuka. Mari kita mulai perjalanan dari tempat yang paling dekat: diri kita sendiri.

#heading(level: 2, numbering: none)[Pendahuluan: Hidup Bertumbuh Melalui Relasi]
<pendahuluan-hidup-bertumbuh-melalui-relasi>
#block[
#callout(
body: 
[
#strong[Kepandaian membuat kita mampu menghasilkan gagasan. Komunikasi membuat gagasan itu dapat dipahami, dipercaya, dikerjakan bersama, dan diubah menjadi nilai tanpa mengorbankan relasi.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#heading(level: 3, numbering: none)[Dapatkah Selembar Kartu Pos Mengubah Arah Hidup?]
<dapatkah-selembar-kartu-pos-mengubah-arah-hidup>
Pada 1970, ketika masih duduk di kelas dua sekolah dasar di Tomohon, Sulawesi Utara, saya menerima kartu-kartu pos dari ayah saya, William Langi. Ketika itu beliau sedang bertugas belajar di San Anselmo, dekat San Francisco. Pada salah satu kartu terdapat gambar Golden Gate yang melintasi muara Teluk San Francisco.

Bagi orang lain, kartu itu mungkin hanya selembar gambar dari tempat yang jauh. Bagi seorang anak di Tomohon, kartu itu membuka sebuah dunia. Saya mulai membayangkan negeri yang belum pernah saya lihat, kehidupan yang hanya saya kenal melalui film, surat kabar, majalah, foto, dan cerita. Dari sana tumbuh sebuah impian: suatu hari saya ingin belajar dan mengalami kehidupan di luar negeri.

Perhatikan apa yang sesungguhnya terjadi. Sebuah pesan melintasi jarak, diterima oleh seorang anak, memperoleh perhatiannya, menumbuhkan minat, melahirkan keinginan, lalu memengaruhi pilihan-pilihan hidupnya selama bertahun-tahun. Kartu pos itu tidak memaksa saya. Ia menghadirkan kemungkinan baru. Komunikasi telah mengubah keadaan batin saya: dari tidak mengetahui, menjadi memperhatikan; dari memperhatikan, menjadi tertarik; dari tertarik, menjadi menginginkan; dan dari menginginkan, menjadi bersedia bertindak.

Bertahun-tahun kemudian, perjalanan itu membawa saya menyelesaikan pendidikan Teknik Elektro ITB pada 1987, menjadi dosen, bergabung dengan PAU Mikroelektronika, mengikuti pelatihan bahasa Inggris, dan mencari kesempatan studi lanjut. Jalannya sama sekali tidak lurus. Saya memasuki pelatihan dengan nilai TOEFL terendah dan nyaris tidak diterima. Setelah berbulan-bulan belajar, saya memperoleh nilai tertinggi dan dipercaya menyampaikan pidato penutupan mewakili peserta dari seluruh Indonesia. Namun, sesudah itu saya masih menerima tujuh surat penolakan dari universitas yang saya lamar sebelum akhirnya diterima di University of Manitoba.

Pengalaman tersebut mengajarkan sesuatu yang lebih luas daripada penguasaan bahasa Inggris. Kemampuan dapat dilatih. Penolakan tidak selalu menjadi akhir cerita. Kesempatan juga tidak lahir dari usaha pribadi semata. Ada instruktur yang mendampingi, lembaga yang membantu, profesor yang bersedia mempertimbangkan, pendahulu yang membangun reputasi, keluarga yang menguatkan, dan banyak orang yang membuka jalan. Hidup saya bergerak melalui relasi.

Mungkin perjalanan Anda tidak dimulai dari sebuah kartu pos. Mungkin ia dimulai dari nasihat orang tua, percakapan dengan sahabat, komentar seorang dosen, video yang mengusik pikiran, pengalaman ditolak, atau seseorang yang mempercayai Anda ketika Anda sendiri masih ragu. Namun, polanya serupa: kata, sikap, kehadiran, dan respons orang lain ikut membentuk siapa kita serta ke mana kita melangkah.

Itulah titik berangkat buku ini: #strong[hidup bertumbuh melalui relasi, dan relasi dibangun melalui komunikasi.]

#heading(level: 3, numbering: none)[Target Harta Karun]
<target-harta-karun-1>
Setelah menyelesaikan Pendahuluan ini, Anda diharapkan memiliki peta awal untuk seluruh perjalanan belajar. Harta karun pertama yang hendak kita peroleh bukanlah teknik berbicara yang mengesankan, melainkan cara pandang yang lebih mendasar: komunikasi adalah kemampuan untuk membangun pengertian, kepercayaan, kesepakatan, tindakan, dan relasi.

Anda dapat menyatakan bahwa harta karun ini mulai menjadi milik Anda apabila mampu:

+ menjelaskan mengapa komunikasi perlu dipahami sebagai proses relasional, bukan sekadar pengiriman pesan;
+ membedakan pribadi, kepribadian, dan peran naratif dalam suatu peristiwa komunikasi;
+ menggambarkan lima domain komunikasi dalam kehidupan Anda;
+ menggunakan TAIDA untuk membaca perubahan keadaan komunikasi;
+ menjelaskan peran AI yang membantu manusia tanpa mengambil alih relasi dan tanggung jawab; serta
+ menyusun peta relasi dan satu sasaran pertumbuhan komunikasi yang konkret.

#heading(level: 3, numbering: none)[Tujuan Belajar]
<tujuan-belajar>
Pada akhir bab ini, Anda mampu:

- merumuskan komunikasi sebagai kompetensi membangun dan menumbuhkan relasi;
- mengenali persoalan komunikasi yang umum dalam kehidupan mahasiswa dan profesional;
- menjelaskan kerangka Pribadi--Kepribadian--Peran Naratif;
- memetakan perkembangan komunikasi dari diri sendiri menuju ruang publik;
- menjelaskan hubungan antara TAIDA, kesepakatan, tindakan, dan relasi;
- menilai secara awal manfaat serta batas kecerdasan buatan dalam komunikasi; dan
- menetapkan bukti awal perkembangan yang akan dikumpulkan selama mempelajari buku.

#heading(level: 3, numbering: none)[Kata Kunci]
<kata-kunci>
#strong[Pribadi (#emph[person])], #strong[kepribadian (#emph[personality])], #strong[peran naratif (#emph[character])], #strong[tujuan], #strong[repertoar], #strong[bahasa], #strong[respons], #strong[relasi], #strong[kepercayaan], #strong[nilai bersama], #strong[TAIDA], #strong[kesepakatan], #strong[tindakan terkoordinasi], #strong[komunikasi berpusat pada manusia], dan #strong[komunikasi berbantuan AI].

#heading(level: 3, numbering: none)[Persiapan: Ingat Satu Percakapan]
<persiapan-ingat-satu-percakapan>
Sebelum membaca lebih jauh, ingatlah satu percakapan yang hasilnya tidak seperti yang Anda harapkan. Pilihlah pengalaman yang cukup aman untuk direnungkan. Anda tidak perlu menggunakan peristiwa yang terlalu pribadi.

Tuliskan jawaban singkat atas pertanyaan berikut:

+ Siapa yang terlibat?
+ Apa yang ingin Anda capai?
+ Apa yang Anda katakan atau lakukan?
+ Bagaimana respons orang lain?
+ Apa hasil akhirnya?
+ Bagaimana keadaan relasi setelah percakapan itu?

Jangan buru-buru menilai siapa yang benar atau salah. Untuk sementara, cukup lihat percakapan itu sebagai sebuah peristiwa yang dapat dipelajari. Kita akan kembali kepadanya setelah memiliki peta yang lebih lengkap.

#heading(level: 3, numbering: none)[Masalahnya Bukan Sekadar Tidak Pandai Berbicara]
<masalahnya-bukan-sekadar-tidak-pandai-berbicara>
Mahasiswa sering membayangkan bahwa persoalan komunikasi terutama berkaitan dengan keberanian tampil di depan kelas. Jika mampu berbicara lancar, membuat presentasi menarik, atau menulis dengan baik, seseorang dianggap telah menguasai komunikasi.

Kemampuan tersebut tentu penting, tetapi belum cukup.

Seseorang dapat berbicara dengan sangat lancar tetapi tidak mendengarkan. Ia dapat membuat slide yang indah tetapi gagal memahami kebutuhan audiens. Ia dapat memenangkan perdebatan tetapi kehilangan sahabat. Ia dapat memperoleh kepatuhan dari anggota tim tetapi merusak kepercayaan. Ia dapat mendapatkan transaksi pertama tetapi membuat pelanggan tidak ingin kembali. Sebaliknya, seseorang yang berbicara sederhana dapat menjadi komunikator yang sangat efektif apabila ia memahami orang yang dihadapi, memilih bahasa yang tepat, membaca respons, dan membangun langkah yang dapat diterima bersama.

Saya memahami bahwa sebagian dari Anda mungkin mengenali diri dalam situasi berikut:

- Anda memiliki gagasan, tetapi tidak tahu bagaimana memulai percakapan.
- Anda memahami materi teknis, tetapi kesulitan menjelaskannya kepada orang dari bidang lain.
- Anda takut dianggap tidak sopan ketika menyatakan ketidaksetujuan.
- Anda mendengarkan teman, tetapi terlalu cepat memberi solusi.
- Anda sudah bekerja keras dalam kelompok, tetapi kesepakatan tetap kabur.
- Anda ingin meminta bantuan, meminta maaf, atau menetapkan batas, tetapi tidak menemukan kata yang tepat.
- Anda memperoleh pesan dari AI yang tampak rapi, tetapi tidak yakin apakah pesan itu jujur, tepat, dan aman untuk dikirimkan.

Pergumulan tersebut bukan bukti bahwa Anda gagal menjadi manusia yang komunikatif. Ia menunjukkan bahwa komunikasi adalah kompetensi yang kompleks. Anda sedang berhadapan dengan pribadi yang mempunyai sejarah, perasaan, nilai, kebutuhan, kepentingan, dan kebebasan memilih. Tidak ada satu kalimat yang selalu berhasil untuk semua orang.

Kabar baiknya, kompetensi ini dapat dipelajari. Anda tidak harus mengubah diri menjadi seorang ekstrover. Anda tidak harus selalu menjadi orang yang paling banyak berbicara. Anda perlu belajar mengenali diri, memahami orang lain, memilih peran dan tujuan, memperluas repertoar, menyesuaikan bahasa, membaca respons, dan bertanggung jawab atas akibat komunikasi.

#heading(level: 3, numbering: none)[Dari Pengiriman Pesan menuju Pembangunan Relasi]
<dari-pengiriman-pesan-menuju-pembangunan-relasi>
Model dasar komunikasi sering digambarkan secara sederhana:

#quote(block: true)[
#strong[Pengirim → Pesan → Penerima]
]

Model ini berguna untuk menjelaskan bahwa pesan berpindah melalui suatu saluran dan dapat terganggu oleh kebisingan. Namun, kehidupan manusia menuntut pandangan yang lebih lengkap. Dalam buku ini, komunikasi dilihat sebagai proses yang melibatkan dua pribadi atau lebih yang saling membaca, merespons, dan membentuk keadaan relasi.

#quote(block: true)[
#strong[Pribadi A ⇄ Komunikasi ⇄ Pribadi B → Pengertian → Relasi → Kesepakatan → Tindakan → Nilai]
]

Panah dua arah mengingatkan bahwa komunikasi bukan pertunjukan tunggal. Ketika Anda berbicara, orang lain memberi respons melalui kata, ekspresi wajah, keheningan, pertanyaan, penerimaan, penolakan, atau perubahan sikap. Respons itu perlu dibaca. Komunikator yang baik tidak sekadar menuntaskan kalimat yang telah disiapkan; ia menggunakan respons untuk memperbarui pemahaman dan menyesuaikan tindakan.

Relasi juga bukan sekadar latar belakang komunikasi. Relasi memengaruhi makna pesan. Kalimat "Kita perlu bicara" dapat terasa menenangkan ketika datang dari sahabat yang dipercaya, tetapi dapat menimbulkan kecemasan ketika dikirim oleh atasan tanpa konteks. Kata yang sama memperoleh makna berbeda karena sejarah, harapan, kekuasaan, dan tingkat kepercayaan dalam relasi.

Karena itu, ukuran keberhasilan komunikasi tidak berhenti pada "pesan telah disampaikan". Kita perlu bertanya:

- Apakah makna yang dimaksud cukup dipahami?
- Apakah orang lain memiliki ruang untuk merespons dan memilih?
- Apakah tercapai kesepakatan atau kejelasan tentang perbedaan?
- Apakah ada tindakan yang dapat dilakukan?
- Apakah relasi menjadi lebih sehat, setidaknya tidak dirusak secara tidak perlu?

Dalam kehidupan profesional, semangat ini sejalan dengan pemikiran Peter Drucker yang menempatkan manusia yang dilayani dan nilai yang diterimanya sebagai pusat pekerjaan organisasi. Produk, teknologi, dan keahlian belum menjadi nilai hanya karena telah selesai dibuat. Nilai hadir ketika hasil pekerjaan tersebut dipahami, digunakan, dan sungguh membantu seseorang. Semua itu memerlukan komunikasi.

#heading(level: 3, numbering: none)[Menjadi Menarik dengan Sungguh-Sungguh Tertarik]
<menjadi-menarik-dengan-sungguh-sungguh-tertarik>
Dalam buku #emph[Daya Tarik], saya pernah menulis bahwa daya tarik pribadi tidak hanya ditentukan oleh tampilan fisik. Penampilan dan pesan nonverbal memang membentuk kesan awal, tetapi daya tarik yang lebih tahan lama tumbuh dari isi pribadi: ketulusan, pengetahuan, empati, keaslian, kisah yang bermakna, konsep yang menjernihkan, dan opini yang disampaikan secara bertanggung jawab.

Pandangan itu perlu kita bawa selangkah lebih jauh. Tujuan komunikasi bukan sekadar membuat diri kita terlihat menarik. Komunikator yang matang belajar #strong[menjadi sungguh-sungguh tertarik kepada orang lain]. Ia mendengarkan bukan untuk menunggu giliran berbicara, melainkan untuk memahami. Ia bertanya bukan untuk menguji, melainkan untuk menemukan makna. Ia menceritakan pengalaman bukan untuk memamerkan diri, melainkan untuk membagikan sesuatu yang mungkin menolong.

Empat bentuk pesan akan sering kita gunakan dalam buku ini:

+ #strong[Kisah pengalaman], yang membantu orang melihat perjuangan, pilihan, dan perubahan.
+ #strong[Kisah inspiratif berbasis fakta], yang menyingkapkan hal menarik di balik suatu peristiwa.
+ #strong[Konsep yang mencerdaskan], yang membantu orang memahami pola dan hubungan.
+ #strong[Opini yang berpengaruh], yang mengajak orang menilai apa yang sebaiknya dilakukan.

Keempatnya dapat menarik perhatian, tetapi hanya akan membangun relasi apabila digunakan dengan niat yang jujur, bukti yang memadai, bahasa yang sesuai, dan penghormatan terhadap kebebasan orang lain.

#heading(level: 3, numbering: none)[Kerangka Utama: Siapa, Menjadi Siapa, untuk Apa, dan Bagaimana?]
<kerangka-utama-siapa-menjadi-siapa-untuk-apa-dan-bagaimana>
Sebelum memilih pesan, kita perlu mengenali unsur-unsur yang membentuk komunikasi.

#quote(block: true)[
#strong[Pribadi → Kepribadian → Peran Naratif → Tujuan → Repertoar → Bahasa → Respons → Kesepakatan → Tindakan → Relasi]
]

#heading(level: 4, numbering: none)[Pribadi]
<pribadi>
Pribadi adalah manusia yang nyata, bukan sekadar kategori. Label seperti "mahasiswa", "pelanggan", "Gen Z", "manajer", atau "masyarakat umum" dapat memberi informasi awal, tetapi tidak pernah menjelaskan seseorang secara utuh. Setiap pribadi membawa sejarah, pengetahuan, nilai, kebutuhan, aspirasi, kemampuan, dan relasi yang berbeda.

Pertanyaan pertama komunikasi bukan "Apa yang ingin saya katakan?", melainkan:

#quote(block: true)[
#strong[Siapa yang sedang saya hadapi?]
]

#heading(level: 4, numbering: none)[Kepribadian]
<kepribadian>
Kepribadian menjelaskan kecenderungan seseorang dalam berpikir, merasakan, dan bertindak. Ada orang yang lebih reflektif, ekspresif, analitis, langsung, berhati-hati, atau mudah membangun keakraban. Kecenderungan membantu kita menyesuaikan komunikasi, tetapi tidak boleh berubah menjadi cap yang membatasi. Kepribadian bukan takdir, dan manusia selalu lebih luas daripada hasil suatu tes.

#heading(level: 4, numbering: none)[Peran Naratif]
<peran-naratif>
Pribadi yang sama dapat hadir dalam peran yang berbeda. Anda dapat menjadi anak dalam keluarga, sahabat dalam percakapan pribadi, mahasiswa di kelas, anggota tim dalam proyek, calon profesional di tempat kerja, pelanggan di pasar, atau warga dalam komunitas. Setiap peran membawa tujuan, tanggung jawab, bahasa, dan tindakan yang berbeda.

Keaslian bukan berarti berbicara dengan cara yang sama kepada semua orang. Keaslian berarti tetap jujur pada nilai diri sambil menjalankan tanggung jawab peran secara tepat.

#heading(level: 4, numbering: none)[Tujuan]
<tujuan>
Tujuan menjawab pertanyaan: perubahan apa yang secara bertanggung jawab ingin dicapai? Tujuan komunikasi dapat berupa memahami, menjelaskan, meminta, mendukung, memperbaiki, mengoordinasikan, menawarkan, bernegosiasi, atau membangun tindakan bersama.

Tujuan yang tidak jelas menghasilkan pesan yang berputar-putar. Tujuan yang tidak etis dapat menghasilkan manipulasi. Karena itu, sebelum berbicara, tanyakan bukan hanya "Apa yang saya inginkan?", tetapi juga "Apakah tujuan ini layak dan menghormati orang lain?"

#heading(level: 4, numbering: none)[Repertoar dan Bahasa]
<repertoar-dan-bahasa>
Repertoar adalah kumpulan cara yang dapat Anda gunakan: mendengarkan, bertanya, menjelaskan, bercerita, memberi contoh, menggunakan data, membuat analogi, memvisualisasikan, bernegosiasi, meminta maaf, diam, atau mengajak mencoba.

Bahasa adalah bentuk yang membuat makna dapat diterima. Gagasan teknis yang sama perlu dijelaskan secara berbeda kepada rekan ahli, manajer, pelanggan, keluarga, dan publik. Menyesuaikan bahasa bukan tindakan berpura-pura; ia merupakan tanggung jawab untuk membuat makna dapat dipahami.

#heading(level: 4, numbering: none)[Respons, Kesepakatan, Tindakan, dan Relasi]
<respons-kesepakatan-tindakan-dan-relasi>
Respons adalah data. Ia memberi tahu apakah orang lain memahami, tertarik, bingung, ragu, keberatan, atau membutuhkan sesuatu yang berbeda. Berdasarkan respons, komunikator menyesuaikan diri.

Kesepakatan tidak selalu berarti semua pihak mempunyai pendapat yang sama. Kesepakatan dapat berupa kejelasan tentang apa yang akan dilakukan, apa yang belum dapat diterima, atau kapan pembicaraan dilanjutkan. Tindakan menjadikan komunikasi berdampak. Relasi menunjukkan apakah kita masih memiliki kemampuan untuk berkomunikasi dan bekerja bersama setelah tindakan berlangsung.

#heading(level: 3, numbering: none)[Lima Domain Kehidupan]
<lima-domain-kehidupan>
Kompetensi yang sama akan dilatih dalam lima lingkar kehidupan.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Domain], [Relasi utama], [Pertanyaan kunci], [Hasil yang diharapkan],),
  table.hline(),
  [#strong[Diri sendiri]], [Saya dengan diri saya], [Cerita apa yang saya sampaikan kepada diri sendiri?], [Kejernihan, regulasi, pilihan, dan pertumbuhan],
  [#strong[Keluarga dan sahabat]], [Saya dengan orang terdekat], [Bagaimana saya hadir, mendengarkan, menyatakan diri, dan memperbaiki relasi?], [Kepercayaan, kedekatan, dukungan, dan rekonsiliasi],
  [#strong[Rekan kerja dan pelanggan]], [Profesional dengan profesional], [Bagaimana kami memahami kebutuhan dan menciptakan nilai bersama?], [Koordinasi, layanan, kesepakatan, dan tindakan],
  [#strong[Tetangga dan komunitas]], [Pribadi dengan komunitas], [Bagaimana kami hidup dan bertindak bersama di tengah perbedaan?], [Partisipasi, mediasi, dan tindakan kolektif],
  [#strong[Dunia]], [Pribadi dengan publik], [Bagaimana gagasan saya memberi kontribusi kepada orang yang mungkin tidak pernah saya jumpai?], [Pemahaman, pengaruh yang bertanggung jawab, dan kontribusi],
)
Perjalanan buku bergerak dari lingkar yang paling dekat menuju lingkar yang semakin luas:

#quote(block: true)[
#strong[Diri → Relasi Dekat → Dunia Profesional → Komunitas → Publik]
]

Anda tidak meninggalkan lingkar sebelumnya ketika memasuki lingkar berikutnya. Kemampuan memahami diri tetap diperlukan ketika bernegosiasi. Empati dalam persahabatan tetap penting ketika melayani pelanggan. Kejelasan profesional tetap berguna ketika berbicara kepada publik. Setiap lingkar memperluas tanggung jawab Anda.

#heading(level: 3, numbering: none)[TAIDA: Membaca Perubahan Keadaan]
<taida-membaca-perubahan-keadaan>
Kartu pos yang saya terima ketika kecil dapat dibaca melalui rute yang kelak kita gunakan berulang kali:

#quote(block: true)[
#strong[Target (Sasaran) → Attention (Perhatian) → Interest (Minat) → Desire (Keinginan) → Action (Tindakan)]
]

#heading(level: 4, numbering: none)[Target (Sasaran)]
<target-sasaran>
Siapa pribadi yang perlu dipahami? Apa situasi, kebutuhan, harapan, dan keadaan relasinya? Komunikasi yang ditujukan kepada "semua orang" sering tidak sungguh-sungguh berbicara kepada siapa pun.

#heading(level: 4, numbering: none)[Attention (Perhatian)]
<attention-perhatian>
Apakah orang tersebut melihat masalah atau peluang yang relevan? Perhatian tidak boleh direbut dengan gangguan atau ketakutan yang tidak perlu. Perhatian diperoleh melalui relevansi, kejelasan, dan kepedulian.

#heading(level: 4, numbering: none)[Interest (Minat)]
<interest-minat>
Apakah ia melihat bahwa ada sesuatu yang layak dipahami lebih lanjut? Minat tumbuh ketika pesan terhubung dengan kebutuhan, aspirasi, atau rasa ingin tahu yang nyata.

#heading(level: 4, numbering: none)[Desire (Keinginan)]
<desire-keinginan>
Apakah ia menginginkan manfaat atau hasil yang ditawarkan? Pada tahap ini, komunikator menjelaskan cara kerja, bukti, manfaat, risiko, dan alternatif. Keinginan yang dibangun secara etis tidak diciptakan dengan menyembunyikan informasi atau mengeksploitasi kerentanan.

#heading(level: 4, numbering: none)[Action (Tindakan)]
<action-tindakan>
Apakah kita dapat mencapai kesepakatan tentang langkah berikutnya? Tindakan memerlukan kejelasan mengenai siapa melakukan apa, kapan, dengan sumber daya apa, serta bagaimana hasilnya ditinjau.

TAIDA bukan alat untuk mendorong orang secara mekanis menuju "ya". Orang dapat mundur, meminta waktu, mengajukan syarat, atau menolak. "Tidak" yang jelas dapat menjadi hasil komunikasi yang lebih sehat daripada "ya" yang diperoleh melalui tekanan. Rute ini membantu kita membaca keadaan dan memilih komunikasi yang sesuai, bukan menghapus kebebasan orang lain.

#heading(level: 3, numbering: none)[Kecerdasan Buatan: Membantu, Bukan Memiliki Relasi]
<kecerdasan-buatan-membantu-bukan-memiliki-relasi>
Kecerdasan buatan dapat membantu komunikasi sebelum, selama, dan sesudah suatu interaksi. Sebelum berkomunikasi, AI dapat membantu menyusun pertanyaan, memetakan pemangku kepentingan, mencoba beberapa pilihan bahasa, atau berlatih menghadapi keberatan. Selama komunikasi, AI dapat membantu transkripsi, penerjemahan, peringkasan, dan aksesibilitas. Sesudahnya, AI dapat membantu merangkum kesepakatan, menemukan hal yang belum jelas, atau meninjau nada pesan.

Namun, AI tidak mengalami relasi sebagaimana manusia mengalaminya. AI tidak menanggung rasa kecewa seorang sahabat, hilangnya kepercayaan pelanggan, akibat sebuah janji, atau tanggung jawab moral dari keputusan yang dibuat. Karena itu, pusat buku ini tetap manusia.

Kita akan mempelajari beberapa peran AI:

- #strong[Cermin], untuk membantu melihat pola komunikasi diri.
- #strong[Pelatih], untuk memberi alternatif dan umpan balik.
- #strong[Penerjemah], untuk menyesuaikan bahasa, kompleksitas, atau format.
- #strong[Kopilot], untuk mendampingi manusia yang tetap membuat keputusan.
- #strong[Mediator], untuk membantu menemukan titik temu dengan pengawasan para pihak.
- #strong[Agen terdelegasi], untuk tugas terbatas dengan kewenangan, batas, dan peninjauan yang jelas.

Prinsip etiknya sederhana:

#quote(block: true)[
#strong[Pengetahuan tentang seseorang harus digunakan untuk meningkatkan pemahaman dan menciptakan nilai bersama, bukan untuk mengeksploitasi kelemahannya.]
]

Komunikasi yang menyangkut permintaan maaf, konflik personal, keputusan nilai, penilaian manusia, atau risiko relasi yang tinggi harus tetap dimiliki manusia. AI boleh membantu persiapan, tetapi kehadiran, pilihan, dan tanggung jawab tidak boleh diserahkan begitu saja.

#heading(level: 3, numbering: none)[Peta Isi Buku]
<peta-isi-buku>
Perjalanan belajar dibagi ke dalam empat bagian.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Bagian], [Fokus], [Perubahan yang diharapkan],),
  table.hline(),
  [#strong[I. Menemukan Diri dan Menjumpai Orang Lain]], [Pribadi, komunikasi dengan diri, keluarga dan sahabat, serta bahasa], [Dari bereaksi secara otomatis menuju memahami diri dan orang lain],
  [#strong[II. Mengubah Komunikasi Menjadi Nilai dan Tindakan]], [Relasi profesional, TAIDA, kesepakatan, dan negosiasi], [Dari menyampaikan gagasan menuju menciptakan nilai dan tindakan bersama],
  [#strong[III. Memperluas Lingkar Relasi]], [Komunitas, publik, dan komunikasi berbantuan AI], [Dari percakapan terbatas menuju kontribusi sosial dan publik yang bertanggung jawab],
  [#strong[IV. Memiliki Harta Karun Itu]], [Integrasi dan proyek puncak], [Dari mengetahui kerangka menuju mampu menggunakannya secara adaptif],
)
Setiap bab menggabungkan Persiapan, Presentasi, Praktis, Unjuk Kerja, dan Refleksi. Anda tidak hanya diminta mengetahui istilah, tetapi menggunakan konsep pada pengalaman nyata, memperoleh umpan balik, dan mencoba kembali.

#heading(level: 3, numbering: none)[Praktis: Membuat Peta Relasi Awal]
<praktis-membuat-peta-relasi-awal>
Sekarang mari kita mulai dari kehidupan Anda sendiri.

Ambil selembar kertas atau dokumen digital. Tuliskan nama Anda di tengah. Buat lima lingkar atau wilayah di sekelilingnya:

+ diri sendiri;
+ keluarga dan sahabat;
+ rekan kerja, tim, atau pelanggan;
+ tetangga dan komunitas; serta
+ publik atau dunia.

Pada setiap wilayah, tuliskan satu sampai tiga relasi yang penting bagi pertumbuhan Anda. Gunakan nama samaran apabila peta ini akan dibagikan. Lalu pilih satu relasi dan isi tabel berikut.

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Unsur], [Catatan Anda],),
  table.hline(),
  [Pribadi yang terlibat], [],
  [Keadaan relasi saat ini], [],
  [Peran yang biasanya saya mainkan], [],
  [Tujuan komunikasi yang penting], [],
  [Kekuatan komunikasi saya], [],
  [Kebiasaan yang menghambat], [],
  [Respons yang sering saya lewatkan], [],
  [Perubahan yang ingin saya capai], [],
)
Peta ini adalah titik awal, bukan penilaian akhir. Anda tidak sedang memberi nilai kepada diri sendiri atau orang lain. Anda sedang belajar melihat relasi secara lebih sadar.

#heading(level: 3, numbering: none)[Unjuk Kerja Awal: Sasaran Pertumbuhan Komunikasi]
<unjuk-kerja-awal-sasaran-pertumbuhan-komunikasi>
Susun sebuah pernyataan sepanjang 150--250 kata dengan judul #strong["Satu Relasi, Satu Kebiasaan, Satu Perubahan"].

Pernyataan Anda perlu menjawab:

+ Relasi atau domain apa yang ingin saya kembangkan?
+ Mengapa relasi tersebut penting?
+ Kebiasaan komunikasi apa yang ingin saya ubah?
+ Perilaku baru apa yang akan saya latih?
+ Bukti apa yang menunjukkan bahwa saya bertumbuh?

Pilih sasaran yang berada dalam jangkauan Anda. Contohnya bukan "Saya akan menjadi komunikator hebat", melainkan "Dalam empat minggu ke depan, saya akan menahan diri untuk tidak langsung memberi solusi ketika seorang teman bercerita. Saya akan merangkum maknanya dan menanyakan apakah ia ingin didengarkan atau membutuhkan saran."

Simpan pernyataan tersebut. Anda akan meninjaunya kembali setelah mempelajari beberapa bab dan membandingkan niat awal dengan bukti perilaku yang sebenarnya.

#heading(level: 3, numbering: none)[Refleksi]
<refleksi>
Kembalilah kepada percakapan yang Anda ingat pada bagian Persiapan. Dengan menggunakan peta bab ini, tanyakan:

- Apakah saya memahami pribadi yang saya hadapi, atau hanya kategorinya?
- Peran apa yang saya mainkan, dan apakah peran itu sesuai?
- Apakah tujuan saya jelas serta bertanggung jawab?
- Repertoar dan bahasa apa yang saya gunakan?
- Respons apa yang diberikan orang lain?
- Di tahap mana percakapan berada: Perhatian, Minat, Keinginan, atau Tindakan?
- Apakah saya memaksakan kemajuan ketika seharusnya mendengarkan?
- Apa hasilnya bagi tindakan dan relasi?

Anda mungkin belum dapat menjawab semuanya. Itu wajar. Pendahuluan ini baru membuka peta. Bab-bab berikutnya akan membantu Anda membaca setiap bagian dengan lebih teliti.

#heading(level: 3, numbering: none)[Ringkasan Satu Menit]
<ringkasan-satu-menit-1>
Komunikasi bukan sekadar mengirimkan pesan. Komunikasi mempertemukan pribadi-pribadi yang membawa sejarah, nilai, kebutuhan, tujuan, dan kebebasan. Karena itu, komunikator perlu mengenali siapa yang dihadapi, menyadari peran yang dimainkan, menetapkan tujuan yang bertanggung jawab, memilih repertoar serta bahasa, membaca respons, dan mengarahkan interaksi menuju pengertian, kesepakatan, tindakan, serta relasi yang sehat.

Perjalanan kita bergerak dari diri sendiri menuju keluarga dan sahabat, dunia profesional, komunitas, dan publik. TAIDA membantu membaca perubahan keadaan dari Target (Sasaran) hingga Action (Tindakan). AI dapat menjadi cermin, pelatih, penerjemah, kopilot, mediator, atau agen terdelegasi, tetapi manusia tetap memiliki relasi dan tanggung jawab.

#quote(block: true)[
#strong[Komunikasi yang efektif = tindakan yang berhasil + relasi yang sehat + tanggung jawab yang terpelihara.]
]

Kita akan memulai bab berikutnya dengan pertanyaan yang paling mendasar: sebelum memikirkan pesan, siapakah manusia yang sedang berkomunikasi?

#heading(level: 1, numbering: none)[Bagian I --- Menemukan Diri dan Menjumpai Orang Lain]
<bagian-i-menemukan-diri-dan-menjumpai-orang-lain-1>
== Komunikasi Dimulai dari Manusia, Bukan dari Pesan
<komunikasi-dimulai-dari-manusia-bukan-dari-pesan>
#block[
#callout(
body: 
[
#strong[Orang yang sama dapat berbicara sebagai anak, sahabat, mahasiswa, pemimpin tim, calon profesional, atau warga. Pribadinya tetap sama, tetapi peran, tujuan, bahasa, dan tanggung jawab komunikasinya dapat berubah.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-2>
Harta karun bab ini adalah kemampuan melihat manusia sebelum menyusun pesan. Setelah mempelajarinya, Anda diharapkan tidak lagi bertanya hanya, "Apa yang akan saya katakan?", tetapi juga, "Siapa yang saya hadapi, sebagai siapa saya hadir, dan relasi seperti apa yang hendak saya bangun?"

Kompetensi ini mulai menjadi milik Anda apabila Anda mampu:

+ membedakan pribadi, kepribadian, dan peran naratif;
+ memilih peran yang sesuai dengan situasi dan tujuan;
+ menghubungkan peran dengan repertoar, bahasa, tindakan, dan relasi;
+ mengenali satu orang dalam beberapa domain kehidupan tanpa mereduksinya menjadi kategori; dan
+ menyusun #emph[Peta Karakter Komunikasi Pribadi] yang realistis.

=== Tujuan Belajar
<tujuan-belajar-1>
Pada akhir bab ini, Anda mampu:

- menjelaskan mengapa komunikasi berlangsung antarmanusia, bukan antarkategori;
- menggunakan kerangka Pribadi--Kepribadian--Peran Naratif secara tepat;
- memetakan tujuan, repertoar, bahasa, respons, tindakan, dan relasi dalam satu peristiwa komunikasi;
- menjelaskan lima domain komunikasi dalam kehidupan sehari-hari;
- menggunakan AI sebagai cermin awal tanpa menyerahkan penilaian identitas kepadanya; dan
- memperlihatkan kemampuan berpindah peran secara autentik.

=== Kata Kunci
<kata-kunci-1>
#strong[Pribadi (#emph[person])], #strong[kepribadian (#emph[personality])], #strong[peran naratif (#emph[narrative character])], #strong[tujuan], #strong[repertoar], #strong[bahasa], #strong[respons], #strong[tindakan], #strong[relasi], #strong[domain komunikasi], #strong[keaslian], dan #strong[cermin AI].

=== Persiapan: Siapa Anda Hari Ini?
<persiapan-siapa-anda-hari-ini>
Tuliskan lima jawaban singkat untuk melengkapi kalimat berikut.

#quote(block: true)[
Hari ini saya hadir sebagai ….
]

Jawaban Anda mungkin berupa anak, kakak, adik, sahabat, mahasiswa, anggota kelompok, pengurus organisasi, pekerja paruh waktu, pelanggan, atau warga. Kemudian, pilih dua peran dan jawab:

- Apa yang ingin saya capai dalam masing-masing peran?
- Apa tanggung jawab saya kepada orang lain?
- Apakah cara bicara saya seharusnya sama?

Latihan sederhana ini mengantar kita kepada satu gagasan penting: #strong[komunikasi selalu memiliki manusia, peran, tujuan, dan relasi sebagai konteksnya.]

=== Attention: Satu Orang, Banyak Peran
<attention-satu-orang-banyak-peran>
Ketika masih anak sekolah dasar di Tomohon, saya menerima kartu pos dari ayah saya yang sedang belajar dekat San Francisco. Dalam kisah itu saya hadir sebagai seorang anak yang sedang bermimpi. Bertahun-tahun kemudian saya menjadi mahasiswa Teknik Elektro ITB, lalu dosen muda di PAU Mikroelektronika. Setelah menikah, saya menjadi suami. Ketika Gladys akan lahir, saya menjadi calon ayah yang harus memutuskan apakah segera berangkat studi atau tetap berada di samping Ina. Dalam program persiapan studi, saya menjadi peserta yang harus berjuang dari nilai TOEFL terendah. Di hadapan peserta lain dan pejabat pendidikan pada penutupan program, saya dipercaya menjadi pembicara.

Orangnya sama. Namun, dalam setiap keadaan, tujuan dan tanggung jawab saya berbeda. Seorang anak boleh bermimpi. Seorang dosen muda perlu belajar dan berkarya. Seorang suami perlu hadir. Seorang peserta pelatihan perlu bertekun. Seorang pembicara perlu mewakili komunitasnya dengan baik.

#block[
#callout(
body: 
[
Perjalanan hidup tidak meminta kita menjadi orang lain setiap kali keadaan berubah. Perjalanan meminta kita menemukan cara yang tepat untuk menghadirkan diri yang sama dalam tanggung jawab yang berbeda. Kemampuan inilah yang dalam bab ini kita sebut memilih #strong[peran naratif].

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Dalam kehidupan Anda pun demikian. Ketika seorang teman mencurahkan isi hati, ia tidak membutuhkan Anda sebagai "pakar yang mengetahui semua jawaban". Ia mungkin membutuhkan Anda sebagai sahabat yang mau mendengarkan. Ketika kelompok proyek kehilangan arah, teman-teman Anda mungkin membutuhkan keberanian Anda untuk hadir sebagai koordinator. Ketika layanan yang Anda beli bermasalah, Anda hadir sebagai pelanggan yang perlu menyatakan kebutuhan dengan tegas namun tetap santun.

Masalah komunikasi kerap terjadi bukan karena kita tidak memiliki kata-kata, melainkan karena kita menghadirkan peran yang tidak sesuai.

=== Interest: Kita Terlalu Cepat Melihat Kategori
<interest-kita-terlalu-cepat-melihat-kategori>
Otak manusia menyukai kategori karena kategori memudahkan pengambilan keputusan. Kita menyebut seseorang "dosen", "mahasiswa", "pelanggan", "orang teknik", "anak pendiam", atau "atasan". Kategori dapat membantu sebagai informasi awal, tetapi berbahaya apabila diperlakukan sebagai keseluruhan identitas.

Seorang dosen bukan hanya dosen. Ia juga dapat menjadi orang tua, peneliti, anggota komunitas, sahabat, dan pribadi yang sedang menghadapi kesulitan. Seorang pelanggan bukan sekadar angka transaksi. Ia mungkin sedang terburu-buru, khawatir, tidak memahami istilah teknis, atau pernah dikecewakan. Seorang mahasiswa yang diam belum tentu tidak tertarik. Ia mungkin sedang berpikir, menjaga kesopanan, belum merasa aman, atau membutuhkan waktu untuk menyusun kata.

Karena itu, kalimat awal kita bukan:

#quote(block: true)[
Saya sedang berbicara kepada sebuah kategori.
]

Melainkan:

#quote(block: true)[
#strong[Saya sedang menjumpai seorang pribadi.]
]

Pendekatan yang berpusat pada pribadi sejalan dengan penghargaan terhadap pengalaman subjektif dan kapasitas manusia untuk bertumbuh @rogers1961becoming. Ia tidak menolak data tentang kelompok atau kecenderungan perilaku. Ia hanya mengingatkan bahwa data tersebut tidak pernah menggantikan perjumpaan dengan manusia konkret di hadapan kita.

=== Desire: Tiga Lapis untuk Memahami Diri dan Orang Lain
<desire-tiga-lapis-untuk-memahami-diri-dan-orang-lain>
==== Pribadi: Siapa yang Bernilai pada Dirinya Sendiri
<pribadi-siapa-yang-bernilai-pada-dirinya-sendiri>
#strong[Pribadi] adalah manusia yang memiliki martabat, sejarah, kebutuhan, nilai, pilihan, serta masa depan. Ia tidak habis dijelaskan oleh jabatan, hasil tes, perilaku sesaat, atau manfaat ekonominya bagi kita.

Melihat pribadi berarti mengakui setidaknya empat hal:

+ Ia mengetahui sebagian hidupnya yang tidak kita ketahui.
+ Ia dapat memberi makna yang berbeda pada peristiwa yang sama.
+ Ia memiliki kebebasan untuk menerima, menolak, atau menegosiasikan ajakan kita.
+ Keadaan dirinya dan relasinya dengan kita dapat berubah.

Pengakuan ini membuat komunikasi lebih rendah hati. Kita belajar bertanya sebelum menyimpulkan, mendengarkan sebelum menasihati, dan memeriksa pemahaman sebelum bertindak.

==== Kepribadian: Kecenderungan, Bukan Takdir
<kepribadian-kecenderungan-bukan-takdir>
#strong[Kepribadian] menunjuk pada kecenderungan yang relatif konsisten, misalnya lebih tenang atau ekspresif, lebih spontan atau terencana, lebih analitis atau intuitif. Kecenderungan membantu kita memperkirakan kebutuhan komunikasi, tetapi tidak boleh menjadi penjara.

Seseorang yang pendiam dapat belajar memimpin rapat. Seseorang yang spontan dapat belajar menyiapkan data. Seseorang yang analitis dapat belajar mengakui perasaan. Seseorang yang ekspresif dapat belajar memberi ruang hening.

Gunakan informasi kepribadian sebagai hipotesis yang perlu diperiksa, bukan vonis yang tidak dapat diubah. Kalimat "Saya memang begini" sebaiknya diganti dengan "Saya cenderung begini, tetapi saya dapat memilih respons yang lebih tepat."

==== Peran Naratif: Saya Sedang Menjadi Siapa?
<peran-naratif-saya-sedang-menjadi-siapa>
#strong[Peran naratif] adalah identitas yang kita hadirkan dan jalankan dalam situasi tertentu. Ia disebut naratif karena manusia memahami hidup melalui cerita: siapa tokohnya, tantangan apa yang dihadapi, nilai apa yang dipertahankan, dan tindakan apa yang dipilih @mcadams2001psychology.

Gagasan ini berdekatan dengan pengamatan bahwa kehidupan sosial memiliki peran dan harapan yang kita tampilkan di hadapan orang lain @goffman1959presentation. Namun, peran naratif dalam buku ini bukan topeng untuk menipu. Ia adalah cara sadar untuk menyelaraskan diri, tanggung jawab, tujuan, dan konteks.

Perhatikan perbedaannya:

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Konsep], [Pertanyaan utama], [Contoh],),
  table.hline(),
  [Pribadi], [Siapakah saya?], [Rina, manusia yang memiliki martabat, sejarah, dan pilihan],
  [Kepribadian], [Bagaimana kecenderungan saya?], [Tenang, teliti, membutuhkan waktu untuk berpikir],
  [Peran naratif], [Saya sedang menjadi siapa di sini?], [Sahabat, mahasiswa, pemimpin proyek, pelanggan, warga],
)
Keaslian bukan berarti menggunakan satu gaya yang sama kepada semua orang. Keaslian berarti nilai inti kita tetap utuh ketika cara kita hadir menyesuaikan tanggung jawab.

=== Dari Peran Menuju Relasi
<dari-peran-menuju-relasi>
Kerangka kerja bab ini dapat dibaca sebagai rangkaian pertanyaan:

#quote(block: true)[
#strong[Pribadi → Kepribadian → Peran Naratif → Tujuan → Repertoar → Bahasa → Respons → Kesepakatan → Tindakan → Relasi]
]

==== Tujuan: Perubahan Apa yang Diharapkan?
<tujuan-perubahan-apa-yang-diharapkan>
Tujuan komunikasi tidak selalu berupa kemenangan atau persetujuan. Tujuan dapat berupa memahami, dipahami, menenangkan, belajar, meminta bantuan, menetapkan batas, mengambil keputusan, atau memulihkan kepercayaan.

Tujuan yang kabur menghasilkan pesan yang melebar. Tujuan yang egoistis dapat menghasilkan tindakan tetapi merusak relasi. Karena itu, rumuskan tujuan dengan dua ukuran:

- #strong[hasil:] perubahan pengetahuan, sikap, kesepakatan, atau tindakan apa yang diharapkan?
- #strong[relasi:] bagaimana orang lain seharusnya mengalami perjumpaan ini?

==== Repertoar: Apa yang Dapat Saya Lakukan?
<repertoar-apa-yang-dapat-saya-lakukan>
Repertoar adalah kumpulan tindakan komunikasi yang tersedia, seperti mendengarkan, bertanya, menceritakan pengalaman, menjelaskan konsep, menyajikan fakta, mengemukakan opini, menggambar, memberi contoh, menyatakan kebutuhan, bernegosiasi, atau berdiam sejenak.

Dalam #emph[Daya Tarik], saya menekankan empat bentuk pesan yang kuat: kisah pengalaman yang luar biasa, kisah inspiratif berbasis fakta, konsep yang mencerdaskan, dan opini yang berpengaruh @langi2025dayatarik. Keempatnya bukan hiasan. Masing-masing berguna untuk tujuan yang berbeda. Kisah membantu orang merasakan; fakta membantu orang memeriksa; konsep membantu orang memahami pola; opini mengundang pertimbangan dan tanggapan.

Komunikator yang hanya memiliki satu repertoar menyerupai pekerja yang hanya membawa satu alat. Jika alat itu tidak sesuai dengan masalah, ia cenderung memaksakannya.

==== Bahasa: Bagaimana Makna Dibawa?
<bahasa-bagaimana-makna-dibawa>
Bahasa mencakup pilihan kata, nada, contoh, simbol, angka, gambar, dan medium. Seorang insinyur dapat berbicara dalam bahasa teknis kepada rekan ahli, bahasa risiko kepada manajer, serta bahasa manfaat kepada pengguna. Kebenaran inti tidak perlu diubah; bentuk penyampaiannya perlu dibuat relevan.

==== Respons, Kesepakatan, Tindakan, dan Relasi
<respons-kesepakatan-tindakan-dan-relasi-1>
Komunikasi belum selesai ketika pesan terkirim. Kita perlu membaca respons: Apakah orang lain memahami? Apakah ia merasa aman untuk bertanya? Apakah ada keberatan? Apakah tujuan perlu disesuaikan?

Respons membuka jalan menuju kesepakatan. Kesepakatan memungkinkan tindakan terkoordinasi. Tindakan kemudian mengubah keadaan relasi. Janji yang dipenuhi menambah kepercayaan; janji yang diabaikan menguranginya. Dengan demikian, keberhasilan komunikasi perlu dinilai pada dua jalur sekaligus:

#quote(block: true)[
#strong[Apakah sesuatu yang bernilai berhasil dilakukan, dan apakah relasi tetap sehat?]
]

=== Lima Domain Komunikasi
<lima-domain-komunikasi>
Kita menjalankan peran dalam lima lingkar kehidupan.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Domain], [Relasi utama], [Contoh peran], [Pertanyaan pertumbuhan],),
  table.hline(),
  [Diri], [Saya dengan diri sendiri], [Pembelajar, pemimpi, perencana], [Cerita apa yang saya katakan kepada diri?],
  [Keluarga dan sahabat], [Saya dengan orang terdekat], [Anak, saudara, sahabat, pasangan], [Apakah saya sungguh hadir dan mendengarkan?],
  [Profesional], [Saya dengan rekan dan pelanggan], [Anggota tim, ahli, pemimpin, pelayan], [Nilai apa yang kita ciptakan bersama?],
  [Komunitas], [Saya dengan tetangga dan kelompok], [Warga, sukarelawan, penggerak], [Bagaimana kita bertindak di tengah perbedaan?],
  [Dunia], [Saya dengan publik luas], [Pembicara, penulis, warga dunia], [Bagaimana pesan saya berdampak secara bertanggung jawab?],
)
Satu orang dapat berada dalam beberapa domain. Rekan kelas dapat menjadi sahabat; anggota keluarga dapat menjadi mitra usaha. Karena itu, aturan formal saja tidak cukup. Kita perlu membaca hubungan yang nyata.

=== AI sebagai Cermin, Bukan Pemberi Label
<ai-sebagai-cermin-bukan-pemberi-label>
AI dapat membantu kita menghasilkan pertanyaan reflektif, membandingkan kemungkinan peran, atau melakukan simulasi percakapan. Misalnya:

#quote(block: true)[
"Saya akan berbicara dengan teman satu tim yang terlambat menyelesaikan tugas. Bantu saya membedakan tujuan, peran, dan pilihan bahasa. Jangan menilai kepribadian kami sebagai fakta."
]

Hasil AI harus diperlakukan sebagai dugaan awal. AI tidak mengalami sejarah relasi, tidak melihat seluruh konteks, dan dapat menghasilkan stereotip. Jangan memasukkan rahasia orang lain atau data pribadi yang tidak perlu. Jangan pula meminta AI menentukan "siapa sebenarnya" seseorang.

#block[
#callout(
body: 
[
Tes kepribadian, analisis percakapan, dan jawaban AI tidak boleh dipakai untuk mengunci identitas. Manusia selalu lebih luas daripada data yang tersedia tentang dirinya.

]
, 
title: 
[
Batas yang Perlu Dijaga
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
=== Praktis: Peta Karakter Komunikasi Pribadi
<praktis-peta-karakter-komunikasi-pribadi>
==== Langkah 1 --- Pilih Lima Peran
<langkah-1-pilih-lima-peran>
Pilih satu peran dari masing-masing domain. Jika suatu domain belum dekat dengan kehidupan Anda, gunakan peran yang ingin Anda kembangkan.

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([Domain], [Peran saya], [Orang yang saya jumpai], [Tanggung jawab utama],),
  table.hline(),
  [Diri], [], [], [],
  [Keluarga/sahabat], [], [], [],
  [Profesional], [], [], [],
  [Komunitas], [], [], [],
  [Dunia/publik], [], [], [],
)
==== Langkah 2 --- Uraikan Dua Peran
<langkah-2-uraikan-dua-peran>
Untuk dua peran yang paling penting saat ini, lengkapi peta berikut.

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Unsur], [Peran A], [Peran B],),
  table.hline(),
  [Tujuan], [], [],
  [Repertoar yang diperlukan], [], [],
  [Bahasa yang sesuai], [], [],
  [Respons yang perlu diperhatikan], [], [],
  [Tindakan yang diharapkan], [], [],
  [Relasi yang hendak dipelihara], [], [],
)
==== Langkah 3 --- Temukan Ketegangan
<langkah-3-temukan-ketegangan>
Tuliskan satu situasi ketika kecenderungan kepribadian Anda kurang mendukung peran. Contoh: "Saya cenderung menghindari konflik, tetapi sebagai koordinator saya perlu menyampaikan masalah." Ubah menjadi sasaran pertumbuhan: "Saya akan belajar menyampaikan masalah secara spesifik, tenang, dan terbuka terhadap tanggapan."

=== Perform: Demonstrasi Pergantian Peran
<perform-demonstrasi-pergantian-peran>
Bekerjalah dalam kelompok tiga orang. Satu orang menjadi pelaku, satu menjadi mitra percakapan, dan satu menjadi pengamat.

Gunakan satu situasi: seorang rekan kelompok belum mengerjakan bagiannya. Pelaku melakukan percakapan singkat dalam tiga peran:

+ sebagai sahabat yang ingin memahami;
+ sebagai anggota tim yang membutuhkan koordinasi; dan
+ sebagai ketua tim yang perlu menetapkan kesepakatan.

Setiap versi berdurasi 60--90 detik. Peran boleh berubah, tetapi penghormatan terhadap pribadi harus tetap sama.

==== Rubrik Kinerja
<rubrik-kinerja>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Kriteria], [Belum tampak], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Ketepatan peran], [Peran tidak jelas], [Peran tampak tetapi tidak konsisten], [Peran jelas dan sesuai situasi],
  [Kejelasan tujuan], [Pesan tanpa arah], [Tujuan ada tetapi melebar], [Tujuan spesifik dan bertanggung jawab],
  [Pilihan repertoar dan bahasa], [Satu cara dipaksakan], [Ada penyesuaian terbatas], [Penyesuaian relevan dan autentik],
  [Perhatian pada respons], [Respons diabaikan], [Respons diperhatikan sebagian], [Respons dipakai untuk menyesuaikan komunikasi],
  [Dampak pada relasi], [Cenderung merusak], [Relasi cukup terjaga], [Tindakan dan relasi sama-sama dipelihara],
)
Simpan peta dan umpan balik sebagai artefak pertama portofolio komunikasi Anda.

=== Refleksi
<refleksi-1>
+ Kategori apa yang paling sering saya gunakan untuk menilai orang terlalu cepat?
+ Dalam situasi apa saya cenderung membawa peran yang keliru?
+ Kecenderungan kepribadian apa yang membantu komunikasi saya? Apa yang perlu dilatih?
+ Apakah perubahan gaya saya merupakan penyesuaian autentik atau upaya memanipulasi?
+ Relasi mana yang akan membaik apabila saya hadir dalam peran yang lebih tepat?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-2>
Komunikasi dimulai dari manusia, bukan dari pesan. Pribadi memiliki martabat, sejarah, kebutuhan, dan pilihan. Kepribadian menggambarkan kecenderungan, bukan takdir. Peran naratif menjawab pertanyaan "Saya sedang menjadi siapa dalam situasi ini?" Peran memengaruhi tujuan, repertoar, dan bahasa; respons mengantar pada kesepakatan serta tindakan; tindakan mengubah relasi.

#quote(block: true)[
#strong[Kenali pribadinya, sadari kecenderungannya, pilih perannya, rumuskan tujuannya, lalu komunikasikan dengan cara yang menjaga tindakan dan relasi.]
]

Pada bab berikutnya, kita bergerak ke percakapan yang mendahului semua percakapan lain: percakapan dengan diri sendiri.

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan>
Gagasan tentang kehadiran sosial, kisah hidup, pertumbuhan pribadi, serta repertoar pesan dalam bab ini dapat didalami melalui #cite(<goffman1959presentation>, form: "prose"), #cite(<mcadams2001psychology>, form: "prose"), #cite(<rogers1961becoming>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== Percakapan dengan Diri Sendiri
<percakapan-dengan-diri-sendiri>
#block[
#callout(
body: 
[
#strong[Sebelum sebuah kata terucap, kita telah memilih perhatian, memberi makna kepada peristiwa, dan menceritakan sesuatu kepada diri sendiri. Cerita batin itu dapat mengurung kita dalam reaksi atau membuka jalan menuju respons yang dipilih.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-3>
Harta karun bab ini adalah kejernihan batin: kemampuan memisahkan apa yang terjadi dari apa yang kita tafsirkan, lalu memilih narasi dan tindakan yang lebih bertanggung jawab. Tujuannya bukan menghapus emosi atau memaksa diri selalu berpikir positif, melainkan memberi ruang antara rangsangan dan respons.

Kompetensi ini mulai menjadi milik Anda apabila Anda mampu:

+ membedakan fakta, interpretasi, dan narasi internal;
+ memetakan alur Peristiwa--Interpretasi--Narasi--Emosi--Pilihan--Tindakan;
+ mengenali peran batin yang sedang dominan;
+ menghasilkan beberapa penafsiran yang masuk akal tanpa menyangkal fakta; dan
+ menyusun jurnal komunikasi intrapribadi yang berakhir pada tindakan nyata.

=== Tujuan Belajar
<tujuan-belajar-2>
Pada akhir bab ini, Anda mampu:

- menjelaskan komunikasi intrapribadi sebagai proses pembentukan makna;
- mengenali hubungan antara narasi internal, emosi, pilihan, dan tindakan;
- membedakan refleksi realistis dari pemikiran positif yang menyangkal keadaan;
- menggunakan dialog batin, jurnal, keheningan, imajinasi, dan latihan mental secara tepat;
- menggunakan AI sebagai cermin reflektif dengan menjaga privasi dan kemandirian; dan
- memperlihatkan perpindahan dari reaksi otomatis menuju respons yang dipilih.

=== Kata Kunci
<kata-kunci-2>
#strong[Komunikasi intrapribadi], #strong[peristiwa], #strong[fakta], #strong[interpretasi], #strong[asumsi], #strong[narasi internal], #strong[emosi], #strong[pilihan], #strong[respons], #strong[peran batin], #strong[jurnal reflektif], #strong[pola pikir bertumbuh], dan #strong[cermin reflektif AI].

=== Persiapan: Ketika Pesan Belum Dibalas
<persiapan-ketika-pesan-belum-dibalas>
Bayangkan Anda mengirim pesan penting kepada seorang teman. Lima jam berlalu dan belum ada jawaban. Lengkapi tiga kalimat berikut dengan jujur.

+ Fakta yang benar-benar saya ketahui adalah ….
+ Cerita pertama yang muncul dalam pikiran saya adalah ….
+ Tindakan yang ingin segera saya lakukan adalah ….

Sekarang tanyakan: apakah kalimat kedua merupakan satu-satunya penjelasan yang mungkin? Pertanyaan itulah pintu masuk menuju komunikasi dengan diri sendiri.

=== Attention: Ketika Tujuh Penolakan Menjadi Sebuah Cerita
<attention-ketika-tujuh-penolakan-menjadi-sebuah-cerita>
Setelah menyelesaikan program persiapan bahasa Inggris, saya berharap jalan menuju studi lanjut akan terbuka. Saya telah berjuang dari nilai TOEFL terendah hingga memperoleh nilai tertinggi dan dipercaya menyampaikan pidato penutupan. Namun, satu demi satu surat dari universitas tiba. Semuanya berisi penolakan. Jumlahnya sampai tujuh.

Peristiwanya sederhana untuk dituliskan: #strong[tujuh permohonan ditolak]. Akan tetapi, peristiwa itu dapat melahirkan banyak cerita batin:

- "Saya memang tidak layak."
- "Semua usaha saya sia-sia."
- "Ada persyaratan yang belum dapat saya penuhi."
- "Saya perlu bantuan dan jalan lain."
- "Tujuh pintu tertutup, tetapi saya belum mengetahui apakah semua pintu telah habis."

Jika saya memperlakukan penolakan sebagai bukti final tentang nilai diri, tindakan saya mungkin berhenti. Jika saya menganggapnya sebagai informasi tentang ketidakcocokan antara persyaratan dan kondisi saya saat itu, saya masih dapat belajar serta menerima pertolongan. WUSC kemudian membantu mendatangi seorang profesor di University of Manitoba. Reputasi baik Budi Rahardjo sebagai mahasiswa ITB yang lebih dahulu berada di sana ikut membuka kepercayaan. Professor Witold Kinsner akhirnya menerima saya.

#block[
#callout(
body: 
[
Tujuh penolakan itu nyata. Rasa kecewa juga nyata. Harapan tidak meminta saya berpura-pura bahwa semuanya baik-baik saja. Harapan meminta saya tidak menjadikan satu rangkaian peristiwa sebagai vonis atas seluruh masa depan.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Kita Bereaksi terhadap Makna yang Kita Bangun
<interest-kita-bereaksi-terhadap-makna-yang-kita-bangun>
Sebelum menjawab orang lain, kita telah melakukan percakapan di dalam diri. Percakapan itu dapat berbentuk kata, gambar, ingatan, sensasi tubuh, kekhawatiran, atau bayangan masa depan. Sering kali prosesnya begitu cepat sehingga interpretasi terasa seperti fakta.

Misalnya, seorang dosen berkata, "Bagian ini perlu diperbaiki."

- Fakta: dosen menyatakan bahwa sebuah bagian perlu diperbaiki.
- Interpretasi A: dosen menganggap saya tidak mampu.
- Interpretasi B: dosen melihat kelemahan pada hasil kerja saya.
- Interpretasi C: saya mendapat informasi untuk meningkatkan mutu pekerjaan.

Interpretasi A dapat memunculkan malu dan sikap defensif. Interpretasi C dapat memunculkan rasa ingin tahu dan pertanyaan, "Bagian mana yang paling perlu saya perbaiki?" Peristiwanya sama, tetapi komunikasi berikutnya berbeda.

Kita tidak selalu dapat memilih emosi pertama yang muncul. Namun, kita dapat belajar memeriksa cerita yang menyertainya dan memilih tindakan yang tidak dikuasai sepenuhnya oleh reaksi pertama.

=== Desire: Peta Percakapan Batin
<desire-peta-percakapan-batin>
Gunakan model berikut:

#quote(block: true)[
#strong[Peristiwa → Interpretasi → Narasi → Emosi → Pilihan → Tindakan → Konsekuensi]
]

==== Peristiwa: Apa yang Dapat Diamati?
<peristiwa-apa-yang-dapat-diamati>
Peristiwa adalah apa yang terjadi atau dapat diperiksa. Deskripsinya sebaiknya spesifik, terikat waktu, dan bebas dari penilaian karakter.

- Pengamatan: "Pesan saya belum dijawab selama lima jam."
- Penilaian: "Ia selalu mengabaikan saya."

Kata "selalu" dan "mengabaikan" telah memasukkan generalisasi serta dugaan tentang niat. Membedakan keduanya tidak berarti kita dilarang menilai. Kita hanya menempatkan penilaian pada lapis yang tepat agar dapat diperiksa.

==== Interpretasi: Makna Awal yang Kita Berikan
<interpretasi-makna-awal-yang-kita-berikan>
Interpretasi menjawab, "Apa arti peristiwa ini bagi saya?" Ia dipengaruhi pengalaman lama, kebutuhan, suasana hati, pengetahuan, dan harapan. Interpretasi diperlukan; tanpa interpretasi kita sulit bertindak. Masalah muncul ketika satu interpretasi dianggap sebagai satu-satunya kenyataan.

Pertanyaan penolong:

- Apa yang benar-benar saya ketahui?
- Apa yang masih saya duga?
- Informasi apa yang belum tersedia?
- Adakah penjelasan lain yang cukup masuk akal?

==== Narasi: Cerita yang Menghubungkan Peristiwa dengan Identitas
<narasi-cerita-yang-menghubungkan-peristiwa-dengan-identitas>
Narasi lebih luas daripada interpretasi tunggal. Ia menghubungkan kejadian dengan cerita tentang diri, orang lain, dan masa depan.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Fakta], [Interpretasi], [Narasi],),
  table.hline(),
  [Lamaran saya ditolak], [Kualifikasi saya belum sesuai], [Saya tidak akan pernah berhasil],
  [Teman membatalkan janji], [Ada kebutuhan lain yang diprioritaskan], [Saya tidak penting bagi siapa pun],
  [Presentasi saya dikritik], [Penjelasan saya belum jelas], [Saya memang tidak berbakat berbicara],
)
Narasi dapat menjadi identitas yang membeku. Karena itu, ubahlah "Saya gagal" menjadi "Upaya ini belum menghasilkan tujuan yang saya harapkan." Kita tidak menghaluskan fakta; kita mencegah satu peristiwa mengambil alih seluruh identitas.

==== Emosi: Informasi, Bukan Komandan Tunggal
<emosi-informasi-bukan-komandan-tunggal>
Emosi memberi informasi tentang sesuatu yang kita anggap penting. Cemas dapat memberi tahu adanya ketidakpastian; marah dapat menandai batas yang dilanggar; sedih dapat menunjukkan kehilangan; gembira dapat menunjukkan pemenuhan kebutuhan atau nilai.

Emosi perlu diakui, dinamai, dan diatur. Menyangkal emosi tidak membuatnya hilang. Namun, mengakui emosi juga tidak berarti setiap dorongan harus dilaksanakan.

==== Pilihan dan Tindakan: Tempat Tanggung Jawab Bertumbuh
<pilihan-dan-tindakan-tempat-tanggung-jawab-bertumbuh>
Pilihan adalah titik tempat kita mempertimbangkan tujuan, nilai, serta konsekuensi. Respons yang dipilih mungkin berupa bertanya, menunda balasan, mencari data, meminta dukungan, menyampaikan batas, meminta maaf, atau menerima kenyataan.

Konsekuensi kemudian menjadi peristiwa baru. Dengan demikian, komunikasi intrapribadi bukan lingkaran tertutup. Ia mengubah cara kita berkomunikasi dengan orang lain dan mengubah relasi.

=== Mengenali Para Tokoh di Dalam Diri
<mengenali-para-tokoh-di-dalam-diri>
Kita dapat memberi nama pada beberapa pola suara batin. Nama ini bukan diagnosis, melainkan alat refleksi.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Peran batin], [Kalimat khas], [Sumbangan], [Risiko jika mendominasi],),
  table.hline(),
  [Hakim], ["Ini salah; seharusnya lebih baik."], [Standar dan evaluasi], [Menghukum diri tanpa jalan perbaikan],
  [Pembela], ["Bukan salah saya."], [Perlindungan dari tuduhan tidak adil], [Menolak tanggung jawab],
  [Pencemas], ["Bagaimana kalau semuanya gagal?"], [Kewaspadaan terhadap risiko], [Membesar-besarkan ancaman],
  [Pemimpi], ["Bagaimana jika ini berhasil?"], [Harapan dan kemungkinan], [Mengabaikan kendala],
  [Pembelajar], ["Apa yang dapat saya pelajari?"], [Rasa ingin tahu dan pertumbuhan], [Terlalu menganalisis tanpa bertindak],
  [Perencana], ["Langkah berikutnya apa?"], [Struktur dan tindak lanjut], [Terlalu kaku],
  [Perawat], ["Apa yang saya butuhkan saat ini?"], [Belas kasih dan pemulihan], [Menghindari tantangan atas nama kenyamanan],
)
Kedewasaan bukan mengusir semua tokoh kecuali satu. Kedewasaan adalah membentuk "ruang rapat batin" yang dipimpin oleh tujuan dan nilai. Pencemas boleh menyampaikan risiko, pemimpi menawarkan kemungkinan, pembelajar mencari pelajaran, perencana menyusun langkah, dan perawat menjaga keberlanjutan. Tidak seorang pun harus menguasai seluruh keputusan.

=== Bukan Sekadar Berpikir Positif
<bukan-sekadar-berpikir-positif>
Komunikasi batin yang sehat tidak berbunyi, "Tidak ada masalah," ketika masalah memang ada. Ia juga tidak menuntut, "Saya pasti berhasil," ketika hasil masih tidak pasti. Narasi yang konstruktif lebih dekat dengan:

#quote(block: true)[
"Keadaan ini sulit dan saya belum mengetahui hasilnya. Saya dapat mencari fakta, meminta bantuan, mempersiapkan diri, dan memilih langkah berikutnya."
]

Pola pikir bertumbuh memandang kemampuan sebagai sesuatu yang dapat dikembangkan melalui strategi, latihan, umpan balik, dan bantuan @dweck2006mindset. Namun, pertumbuhan bukan janji bahwa setiap tujuan pasti tercapai. Pertumbuhan adalah komitmen untuk belajar dari proses serta menyesuaikan tindakan secara realistis.

=== Repertoar Komunikasi dengan Diri
<repertoar-komunikasi-dengan-diri>
==== Dialog dan Pertanyaan Reflektif
<dialog-dan-pertanyaan-reflektif>
Gunakan pertanyaan yang membuka penyelidikan, bukan menggelar pengadilan.

- Alih-alih "Mengapa saya selalu bodoh?", tanyakan "Bagian mana yang belum saya pahami?"
- Alih-alih "Mengapa mereka membenci saya?", tanyakan "Respons apa yang saya amati, dan penjelasan apa yang belum saya periksa?"
- Alih-alih "Bagaimana agar saya tidak takut?", tanyakan "Tindakan kecil apa yang tetap dapat saya lakukan sambil merasa takut?"

==== Jurnal
<jurnal>
Menulis memperlambat pikiran. Jurnal membuat fakta, asumsi, emosi, dan pilihan terlihat sebagai unsur yang berbeda. Tulisan tidak perlu indah. Yang dibutuhkan ialah kejujuran dan struktur.

==== Keheningan dan Kesadaran Tubuh
<keheningan-dan-kesadaran-tubuh>
Berhenti sejenak membantu kita mengenali napas yang pendek, rahang yang menegang, atau dorongan untuk segera membalas. Keheningan bukan kekosongan; ia dapat menjadi ruang untuk memulihkan pilihan.

==== Imajinasi dan Latihan Mental
<imajinasi-dan-latihan-mental>
Kita dapat membayangkan percakapan sulit, mencoba beberapa kalimat, serta memperkirakan respons. Tujuannya bukan mengendalikan orang lain, melainkan mempersiapkan diri agar mampu hadir.

=== TAIDA di Dalam Diri
<taida-di-dalam-diri>
TAIDA juga dapat dibaca sebagai perubahan keadaan internal.

- #strong[Target (Sasaran):] keadaan diri atau tindakan apa yang ingin dicapai?
- #strong[Attention (Perhatian):] fakta dan sinyal apa yang perlu saya lihat?
- #strong[Interest (Minat):] mengapa peristiwa ini penting bagi nilai dan kebutuhan saya?
- #strong[Desire (Keinginan):] keadaan yang lebih baik seperti apa yang saya inginkan?
- #strong[Action (Tindakan):] langkah kecil dan nyata apa yang saya pilih?

TAIDA mencegah kita melompat dari rangsangan langsung ke tindakan tanpa memahami apa yang sedang berlangsung.

=== AI sebagai Cermin Reflektif
<ai-sebagai-cermin-reflektif>
AI dapat membantu mengajukan pertanyaan, memisahkan fakta dari dugaan, menghasilkan penafsiran alternatif, atau menjadi mitra latihan. Contoh perintah:

#quote(block: true)[
"Berikut deskripsi singkat sebuah peristiwa tanpa nama dan data pribadi. Pisahkan pengamatan, interpretasi, dan asumsi. Ajukan lima pertanyaan reflektif. Jangan mendiagnosis saya dan jangan menentukan keputusan akhir."
]

Gunakan tiga pagar pengaman:

+ #strong[Privasi:] hilangkan nama, identitas, rahasia, informasi medis, dan data sensitif.
+ #strong[Verifikasi:] jawaban AI dapat keliru atau terlalu meyakinkan; periksa terhadap fakta dan nilai Anda.
+ #strong[Kemandirian:] keputusan moral dan relasional tetap milik Anda. AI membantu berpikir, bukan mengambil alih kehidupan.

Jika suatu peristiwa menimbulkan bahaya, kekerasan, keinginan menyakiti diri, atau gangguan yang berat dan berkepanjangan, jurnal serta AI bukan pengganti bantuan manusia yang kompeten. Hubungi orang tepercaya dan layanan profesional yang sesuai.

=== Praktis: Tiga Narasi atas Satu Peristiwa
<praktis-tiga-narasi-atas-satu-peristiwa>
Pilih satu peristiwa sulit yang cukup aman untuk dipelajari. Tuliskan tiga versi:

+ #strong[Narasi korban:] semua kendali berada di luar diri dan tidak ada pilihan.
+ #strong[Narasi analitis:] bedakan fakta, penafsiran, hal yang belum diketahui, dan faktor yang dapat dikendalikan.
+ #strong[Narasi pertumbuhan:] akui kesulitan, temukan pelajaran, dan pilih langkah yang sesuai nilai.

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Unsur], [Catatan Anda],),
  table.hline(),
  [Peristiwa yang dapat diamati], [],
  [Interpretasi pertama], [],
  [Emosi dan sensasi tubuh], [],
  [Narasi korban], [],
  [Narasi analitis], [],
  [Narasi pertumbuhan], [],
  [Pilihan tindakan], [],
  [Dukungan yang diperlukan], [],
)
Bandingkan ketiganya. Narasi mana yang paling akurat? Mana yang paling membantu? Narasi yang membantu tetapi tidak akurat dapat menyesatkan; narasi yang akurat tetapi tanpa belas kasih dapat melumpuhkan. Carilah keduanya.

=== Perform: Jurnal Komunikasi Intrapribadi
<perform-jurnal-komunikasi-intrapribadi>
Selama tiga hari, catat satu peristiwa per hari dengan format berikut:

+ #strong[Peristiwa:] apa yang terjadi?
+ #strong[Cerita awal:] apa yang langsung saya katakan kepada diri?
+ #strong[Emosi:] apa yang saya rasakan dan seberapa kuat (0--10)?
+ #strong[Peran batin:] siapa yang paling dominan?
+ #strong[Tujuan:] keadaan atau nilai apa yang ingin saya jaga?
+ #strong[Alternatif:] penafsiran lain apa yang masuk akal?
+ #strong[Tindakan:] respons apa yang saya pilih?
+ #strong[Konsekuensi:] apa yang berubah pada hasil dan relasi?
+ #strong[Pelajaran:] apa yang ingin saya ulangi atau perbaiki?

==== Rubrik Kinerja
<rubrik-kinerja-1>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Kriteria], [Belum tampak], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Pemisahan fakta dan cerita], [Bercampur], [Sebagian terpisah], [Jelas dan dapat diperiksa],
  [Keragaman interpretasi], [Hanya satu vonis], [Ada alternatif terbatas], [Alternatif masuk akal dan bernuansa],
  [Kesadaran emosi], [Diabaikan atau dikuasai], [Dinamai secara umum], [Dinamai dan dihubungkan dengan kebutuhan/nilai],
  [Pilihan tindakan], [Reaktif atau kabur], [Ada tindakan tetapi belum terukur], [Spesifik, realistis, dan bertanggung jawab],
  [Refleksi konsekuensi], [Tidak ada], [Menilai hasil saja], [Menilai hasil, relasi, dan pelajaran],
)
=== Refleksi
<refleksi-2>
+ Cerita apa yang paling sering saya ulangi tentang diri sendiri?
+ Apakah cerita itu merupakan fakta, interpretasi, atau warisan penilaian lama?
+ Peran batin mana yang paling sering mengambil alih?
+ Apa yang berubah ketika saya memberi diri waktu sebelum merespons?
+ Dukungan manusia apa yang perlu saya minta?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-3>
Kita tidak hanya bereaksi terhadap peristiwa, tetapi juga terhadap makna yang kita bangun. Dengan memisahkan peristiwa, interpretasi, narasi, emosi, pilihan, dan tindakan, kita memperoleh ruang untuk merespons. Komunikasi intrapribadi yang sehat bukan penyangkalan atau optimisme kosong; ia memadukan ketepatan fakta, belas kasih kepada diri, keterbukaan untuk belajar, dan keberanian bertindak.

#quote(block: true)[
#strong[Saya tidak selalu dapat memilih peristiwa atau emosi pertama, tetapi saya dapat belajar memeriksa cerita dan memilih langkah berikutnya.]
]

Pada bab selanjutnya, ruang refleksi ini kita bawa menuju relasi yang paling dekat: keluarga dan sahabat.

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-1>
Pembahasan tentang cerita hidup, penerimaan diri, pola pikir bertumbuh, serta ketekunan dalam bab ini dapat didalami melalui #cite(<mcadams2001psychology>, form: "prose"), #cite(<rogers1961becoming>, form: "prose"), #cite(<dweck2006mindset>, form: "prose"), dan kisah pengalaman dalam #cite(<langi2025dayatarik>, form: "prose").

== Keluarga dan Sahabat: Relasi yang Perlu Dihadirkan
<keluarga-dan-sahabat-relasi-yang-perlu-dihadirkan>
#block[
#callout(
body: 
[
#strong[Orang terdekat tidak hanya membutuhkan kata-kata yang baik. Mereka membutuhkan perhatian, waktu, keberanian untuk berkata jujur, serta kesediaan memperbaiki hubungan ketika kita melukai atau gagal memahami.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-4>
Harta karun bab ini adalah kemampuan memperoleh, memelihara, memperbaiki, dan menumbuhkan relasi personal melalui komunikasi yang empatik serta asertif. Ukuran keberhasilannya bukan bahwa semua orang selalu setuju, melainkan bahwa perbedaan dapat dibicarakan tanpa menghilangkan martabat, kebutuhan, batas, dan tanggung jawab.

Kompetensi ini mulai menjadi milik Anda apabila Anda mampu:

+ mendengarkan kata, makna, dan pribadi;
+ membedakan memahami, menyetujui, memvalidasi, dan membenarkan;
+ menyatakan pengamatan, perasaan, kebutuhan, dan permintaan secara spesifik;
+ menetapkan batas tanpa menyerang;
+ melakukan percakapan perbaikan relasi; dan
+ mengevaluasi perubahan keadaan relasi sesudah komunikasi.

=== Tujuan Belajar
<tujuan-belajar-3>
Pada akhir bab ini, Anda mampu:

- menjelaskan relasi sebagai karya yang dibangun bersama;
- mengenali empat tugas komunikasi relasional: memperoleh, memelihara, memperbaiki, dan menumbuhkan;
- mempraktikkan rasa ingin tahu, mendengarkan, validasi, penghargaan, dan komunikasi asertif;
- menggunakan formula Observasi--Perasaan--Kebutuhan--Permintaan;
- menyusun permintaan maaf dan rencana perbaikan yang bertanggung jawab;
- menjelaskan batas etis penggunaan AI dalam percakapan intim; dan
- mendemonstrasikan satu percakapan perbaikan relasi.

=== Kata Kunci
<kata-kunci-3>
#strong[Relasi interpersonal], #strong[kepercayaan], #strong[kehadiran], #strong[mendengarkan], #strong[rasa ingin tahu], #strong[validasi], #strong[penghargaan], #strong[asertif], #strong[batas sehat], #strong[observasi], #strong[perasaan], #strong[kebutuhan], #strong[permintaan], #strong[permintaan maaf], #strong[pengampunan], dan #strong[perbaikan relasi].

=== Persiapan: Orang Terdekat yang Kurang Terdengar
<persiapan-orang-terdekat-yang-kurang-terdengar>
Pilih satu relasi yang penting dan cukup aman untuk direnungkan. Jangan memilih situasi kekerasan atau ancaman yang membutuhkan bantuan profesional.

Tuliskan:

- hal terakhir yang orang itu ceritakan kepada Anda;
- kebutuhan atau nilai yang mungkin berada di balik ceritanya;
- respons yang Anda berikan; dan
- apa yang mungkin ia rasakan setelah menerima respons Anda.

Jika Anda tidak dapat mengingat apa yang terakhir ia ceritakan, jangan menghukum diri. Anggaplah itu undangan untuk hadir lebih sungguh-sungguh.

=== Attention: Ketika Impian Perlu Menunggu
<attention-ketika-impian-perlu-menunggu>
Pada Juni 1989, akhirnya saya memperoleh satu surat penerimaan dari University of Manitoba setelah tujuh penolakan. Waktu keberangkatan sudah dekat. Namun, Ina sedang mengandung dan Gladys diperkirakan lahir pada September. Saya harus memulai studi pada Agustus, sementara Ina belum dapat ikut.

Impian ke luar negeri telah saya bawa sejak kelas dua sekolah dasar. Jalan ke sana panjang: menyelesaikan Teknik Elektro ITB, menjadi dosen, memasuki program bahasa Inggris dengan nilai TOEFL terendah, belajar keras, dan mencari universitas yang bersedia menerima. Kesempatan itu sangat berharga. Akan tetapi, ada relasi yang juga sangat berharga dan tidak dapat diwakili oleh kalimat indah dari kejauhan.

Saya memutuskan menunda keberangkatan untuk mendampingi Ina dan menyambut kelahiran Gladys. Ketika rombongan teman berangkat, ada rasa kosong. Namun, ruang itu segera diisi kegembiraan menantikan anak kami. Impian dapat menunggu; kehadiran pada momen tertentu tidak selalu dapat diulang.

#block[
#callout(
body: 
[
Komunikasi bukan hanya apa yang kita ucapkan. Waktu yang kita berikan, prioritas yang kita pilih, janji yang kita penuhi, dan kesediaan kita hadir juga berbicara. Kadang-kadang pesan kasih yang paling kuat berbentuk keputusan.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Kisah ini bukan resep bahwa setiap orang harus mengambil keputusan yang sama. Kondisi keluarga, kesehatan, ekonomi, dan tanggung jawab dapat berbeda. Pelajarannya lebih mendasar: relasi yang penting perlu masuk ke dalam pertimbangan nyata, bukan sekadar disebut penting.

=== Interest: Mengapa Orang Terdekat Kadang Paling Sulit Didengarkan?
<interest-mengapa-orang-terdekat-kadang-paling-sulit-didengarkan>
Kedekatan memberi kita sejarah bersama. Sejarah itu dapat menjadi sumber kepercayaan, tetapi juga sumber asumsi. Kita merasa sudah mengenal orang terdekat sehingga berhenti bertanya. Kita menyelesaikan kalimatnya, menafsirkan nadanya melalui konflik lama, atau segera menawarkan solusi yang pernah kita berikan.

Ada pula godaan untuk membawa peran yang salah. Seorang kakak terus hadir sebagai pengatur ketika adiknya telah dewasa. Seorang sahabat hadir sebagai hakim ketika temannya membutuhkan pendengar. Seorang mahasiswa membawa bahasa rapat proyek ke percakapan keluarga yang sedang terluka.

Mendengarkan orang terdekat membutuhkan disiplin untuk berkata dalam hati:

#quote(block: true)[
"Saya memiliki sejarah dengannya, tetapi saya belum tentu telah memahami pengalamannya hari ini."
]

=== Desire: Relasi sebagai Karya Bersama
<desire-relasi-sebagai-karya-bersama>
Relasi bukan benda yang dimiliki satu pihak. Relasi berada di antara dua pribadi dan dibentuk oleh pengalaman bersama, ingatan, janji, tindakan, kekecewaan, pengampunan, dan harapan.

Secara sederhana:

#quote(block: true)[
#strong[Keadaan Relasi(t) + Komunikasi + Tindakan → Keadaan Relasi(t+1)]
]

Satu percakapan jarang menentukan seluruh relasi, tetapi setiap percakapan memberi sumbangan. Perhatian yang konsisten menumbuhkan kepercayaan. Penghinaan yang berulang mengikis rasa aman. Permintaan maaf yang diikuti perubahan dapat memulai pemulihan.

Empat tugas besar komunikasi relasional ialah:

+ #strong[Memperoleh (#emph[acquire]):] membuka hubungan dan membangun rasa aman awal.
+ #strong[Memelihara (#emph[maintain]):] menjaga perhatian, keandalan, dan rasa saling memiliki.
+ #strong[Memperbaiki (#emph[repair]):] mengakui luka, mendengar dampak, serta melakukan perubahan.
+ #strong[Menumbuhkan (#emph[grow]):] memperdalam pengertian, pengalaman, makna, dan aspirasi bersama.

Tidak semua relasi harus menjadi intim. Kedalaman harus tumbuh dengan persetujuan dan keamanan, bukan dipaksa.

=== Mendengarkan pada Tiga Tingkat
<mendengarkan-pada-tiga-tingkat>
==== Tingkat 1 --- Mendengar Kata
<tingkat-1-mendengar-kata>
Pada tingkat ini kita menangkap isi literal. "Saya lelah mengerjakan proyek ini." Kita mengetahui topiknya, tetapi belum tentu memahami maksudnya.

==== Tingkat 2 --- Memahami Makna
<tingkat-2-memahami-makna>
Kita mencari arti di balik kata. Apakah "lelah" berarti beban terlalu banyak, konflik tim, kehilangan motivasi, atau kurang tidur? Kita memeriksa dengan parafrasa:

#quote(block: true)[
"Kalau saya memahami dengan benar, yang paling melelahkan bukan jumlah tugasnya, tetapi ketidakjelasan pembagian kerja. Benarkah?"
]

==== Tingkat 3 --- Memahami Pribadi
<tingkat-3-memahami-pribadi>
Kita berusaha melihat apa yang penting bagi orang itu: kebutuhan, nilai, ketakutan, harapan, serta sejarahnya. Kita tidak mengambil alih pengalamannya, tetapi hadir dengan empati.

#quote(block: true)[
"Kamu ingin kontribusimu dihargai dan pembagian tanggung jawab terasa adil."
]

Mendengarkan pada tingkat ketiga bukan membaca pikiran. Karena itu, gunakan bahasa tentatif---"apakah", "mungkin", "kalau saya memahami"---dan beri ruang untuk koreksi.

=== Rasa Ingin Tahu tanpa Menginterogasi
<rasa-ingin-tahu-tanpa-menginterogasi>
Pertanyaan yang baik lahir dari kepedulian, bukan keinginan menguasai. Bandingkan:

- Interogasi: "Mengapa kamu tidak bilang dari dulu? Siapa yang salah?"
- Rasa ingin tahu: "Kapan kamu mulai merasakan ini? Bagian mana yang paling berat?"

Tanda rasa ingin tahu yang sehat:

- orang lain boleh tidak menjawab;
- pertanyaan mengikuti cerita, bukan daftar kita;
- kita tidak mencari celah untuk membantah;
- kita bersedia mendengar jawaban yang tidak sesuai dugaan.

=== Memahami Tidak Sama dengan Menyetujui
<memahami-tidak-sama-dengan-menyetujui>
Kita dapat memahami alasan seseorang tanpa menyetujui keputusan atau tindakannya. Pemahaman menjawab, "Dapatkah saya melihat bagaimana ia sampai pada pandangan itu?" Persetujuan menjawab, "Apakah saya menerima pandangan atau usulan itu?"

Demikian pula, #strong[validasi tidak sama dengan pembenaran]. Kalimat "Saya memahami mengapa kamu kecewa" mengakui pengalaman emosi. Kalimat itu tidak otomatis berarti kita menyetujui tuduhan, menerima perilaku kasar, atau menyerahkan batas.

Pembedaan ini penting karena banyak orang takut mendengarkan: mereka khawatir pemahaman akan dianggap sebagai kekalahan. Padahal, pemahaman justru membuat perbedaan dapat dibicarakan dengan lebih tepat.

=== Menyatakan Diri tanpa Menyerang
<menyatakan-diri-tanpa-menyerang>
Empati tidak berarti menghilangkan suara sendiri. Relasi sehat membutuhkan kemampuan mendengarkan dan menyatakan diri. Salah satu kerangka yang berguna ialah Observasi--Perasaan--Kebutuhan--Permintaan, yang berakar pada komunikasi nirkekerasan @rosenberg2015nonviolent.

==== Observasi
<observasi>
Sebutkan perilaku yang dapat diamati tanpa memberi label karakter.

- Serangan: "Kamu tidak bertanggung jawab."
- Observasi: "Dua tugas yang kita sepakati belum diserahkan sampai batas waktu."

==== Perasaan
<perasaan>
Nyatakan pengalaman emosi sebagai milik Anda.

- Menyalahkan: "Kamu membuat saya stres."
- Perasaan: "Saya khawatir dan kewalahan."

==== Kebutuhan
<kebutuhan>
Jelaskan nilai atau kebutuhan yang penting.

#quote(block: true)[
"Saya membutuhkan kepastian agar bagian lain dapat diselesaikan."
]

==== Permintaan
<permintaan>
Ajukan tindakan yang spesifik, realistis, dapat dijawab, dan terbuka untuk negosiasi.

#quote(block: true)[
"Apakah kamu bersedia mengirimkan draf pertama sebelum pukul 19.00, atau memberi tahu sekarang jika kita perlu membagi ulang tugas?"
]

Formula lengkapnya:

#quote(block: true)[
#strong["Ketika saya mengamati …, saya merasa …, karena saya membutuhkan/menghargai …. Apakah Anda bersedia …?"]
]

Formula ini bukan mantra. Jika dibacakan secara mekanis, ia dapat terdengar dingin atau manipulatif. Gunakan sebagai peta berpikir, lalu ungkapkan dengan bahasa yang wajar bagi relasi Anda.

=== Batas Sehat dan Komunikasi Asertif
<batas-sehat-dan-komunikasi-asertif>
Batas menjelaskan apa yang dapat kita terima, apa yang tidak, dan tindakan apa yang akan kita ambil untuk menjaga keselamatan serta integritas. Batas bukan ancaman untuk mengendalikan orang lain.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Gaya], [Ciri], [Contoh],),
  table.hline(),
  [Pasif], [Kebutuhan diri disembunyikan], ["Tidak apa-apa," meski terus terluka],
  [Agresif], [Kebutuhan dipaksakan dengan merendahkan], ["Kamu harus berubah atau kamu memang buruk."],
  [Asertif], [Kebutuhan dan batas disampaikan jelas sambil menghormati], ["Saya bersedia melanjutkan percakapan ketika kita dapat berbicara tanpa makian."],
)
Dalam situasi kekerasan, ancaman, atau kontrol yang membahayakan, tujuan utama bukan mempertahankan percakapan, melainkan mencari keselamatan dan bantuan. Komunikasi yang baik tidak mewajibkan seseorang bertahan dalam bahaya.

=== Memelihara dan Menumbuhkan Relasi
<memelihara-dan-menumbuhkan-relasi>
Relasi jarang tumbuh hanya melalui percakapan besar. Ia dipelihara oleh tindakan kecil yang dapat diandalkan:

- memberi perhatian tanpa selalu menunggu masalah;
- menepati janji atau segera memberi kabar ketika keadaan berubah;
- mengucapkan penghargaan secara spesifik;
- merayakan pertumbuhan orang lain tanpa menjadikannya persaingan;
- menciptakan pengalaman bersama;
- mengingat hal yang penting bagi orang lain; dan
- memberi ruang bagi perubahan.

Penghargaan yang spesifik lebih bermakna daripada pujian umum. Alih-alih "Kamu hebat," katakan, "Ketika kamu menunggu saya selesai berbicara dan merangkum kekhawatiran saya, saya merasa sungguh didengarkan."

=== Ketika Relasi Terluka
<ketika-relasi-terluka>
Kesalahan tidak otomatis mengakhiri relasi. Penyangkalan, pengulangan, dan keengganan memperbaiki sering kali lebih merusak daripada kesalahan awal.

Gunakan lima langkah perbaikan:

+ #strong[Akui:] sebutkan tindakan tanpa mengecilkan atau mengalihkan.
+ #strong[Dengarkan:] beri ruang bagi orang lain menjelaskan dampak.
+ #strong[Miliki tanggung jawab:] bedakan penjelasan dari alasan pembenar.
+ #strong[Perbaiki:] tawarkan pemulihan yang konkret.
+ #strong[Sepakati:] tentukan perubahan atau batas ke depan.

Permintaan maaf yang matang dapat berbunyi:

#quote(block: true)[
"Saya terlambat dan tidak memberi kabar, padahal kita telah berjanji. Saya memahami bahwa kamu menunggu dan merasa waktumu tidak dihargai. Saya minta maaf. Mulai sekarang saya akan memberi kabar sebelum waktu pertemuan jika terhambat. Apa ada hal lain yang perlu saya dengar atau perbaiki?"
]

Hindari permintaan maaf semu: "Maaf kalau kamu tersinggung." Kalimat itu menempatkan masalah pada reaksi orang lain, bukan tindakan kita.

Pengampunan tidak sama dengan melupakan, menghapus konsekuensi, atau memulihkan kedekatan seketika. Kepercayaan dapat membutuhkan bukti perubahan yang konsisten. Pihak yang terluka memiliki hak untuk menentukan jarak yang aman.

=== AI sebagai Pelatih, Bukan Pengganti Kehadiran
<ai-sebagai-pelatih-bukan-pengganti-kehadiran>
AI dapat membantu meninjau nada, membuat beberapa versi permintaan, menguji apakah observasi masih mengandung penilaian, atau mensimulasikan respons. Contoh:

#quote(block: true)[
"Tinjau pesan berikut. Tandai label karakter, tuduhan, atau permintaan yang tidak spesifik. Buat dua versi yang lebih asertif tanpa menghapus batas saya."
]

Namun, jangan menyerahkan percakapan intim sepenuhnya kepada AI. Pesan yang sangat rapi tetapi tidak mencerminkan suara Anda dapat terasa asing. Jangan memasukkan rahasia orang lain. Jangan menggunakan AI untuk memanipulasi emosi, menyamar sebagai orang lain, atau menghasilkan kedekatan palsu.

#quote(block: true)[
#strong[AI dapat membantu menyiapkan kata. Hanya manusia yang dapat mengambil tanggung jawab, hadir, mendengar dampak, dan menepati perubahan.]
]

=== Praktis: Mendengarkan tanpa Memperbaiki
<praktis-mendengarkan-tanpa-memperbaiki>
Bekerjalah berpasangan. Pembicara menceritakan masalah ringan selama tiga menit. Pendengar tidak memberi solusi kecuali diminta. Tugas pendengar:

+ memberi perhatian penuh;
+ mengajukan maksimal dua pertanyaan terbuka;
+ merangkum makna;
+ menebak perasaan atau kebutuhan secara tentatif; dan
+ bertanya, "Apakah kamu ingin didengarkan, dibantu memikirkan pilihan, atau memperoleh saran?"

Setelah berganti peran, masing-masing memberi umpan balik: pada saat apa saya paling merasa didengarkan? Pada saat apa pendengar membuat asumsi?

=== Perform: Percakapan Perbaikan Relasi
<perform-percakapan-perbaikan-relasi>
Pilih kasus nyata yang aman atau gunakan studi kasus berikut:

#quote(block: true)[
Dua sahabat mengerjakan proyek bersama. Salah satu mengubah bagian presentasi tanpa berdiskusi. Yang lain merasa kontribusinya tidak dihargai dan mulai menjauh.
]

Susun dan peragakan percakapan 4--6 menit yang mencakup:

- pembukaan yang aman;
- observasi tanpa label;
- pengungkapan perasaan dan kebutuhan;
- mendengarkan serta validasi;
- permintaan atau batas yang spesifik;
- pengakuan tanggung jawab; dan
- kesepakatan tindak lanjut.

==== Rubrik Kinerja
<rubrik-kinerja-2>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Kriteria], [Belum tampak], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Kehadiran dan mendengarkan], [Memotong atau menyiapkan bantahan], [Mendengar isi utama], [Menangkap kata, makna, dan pribadi],
  [Kejelasan ungkapan], [Menuduh atau kabur], [Sebagian spesifik], [Observasi, perasaan, kebutuhan, permintaan jelas],
  [Asertivitas], [Pasif atau agresif], [Batas ada tetapi goyah], [Batas tegas dan tetap menghormati],
  [Perbaikan], [Membela diri], [Mengakui sebagian], [Mengakui dampak dan menawarkan perubahan nyata],
  [Dampak relasional], [Ketegangan meningkat tanpa arah], [Ada pengertian awal], [Ada kesepakatan atau langkah aman berikutnya],
)
Setelah demonstrasi, jangan hanya menilai kelancaran. Tanyakan apakah keadaan relasi bergerak dari tegang menuju cukup aman untuk berbicara, dari tidak dipahami menuju dipahami, atau dari luka menuju langkah awal perbaikan.

=== Refleksi
<refleksi-3>
+ Apakah saya lebih sering memperbaiki masalah atau berusaha memperbaiki orang?
+ Kapan saya memberi solusi sebelum memahami?
+ Apakah saya dapat mengakui perasaan orang lain tanpa segera menyetujui kesimpulannya?
+ Batas apa yang perlu saya nyatakan dengan lebih jelas?
+ Tindakan kecil apa yang dapat saya lakukan minggu ini untuk menghadirkan satu relasi penting?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-4>
Relasi adalah karya bersama yang berubah melalui komunikasi dan tindakan. Kita memperolehnya melalui perhatian dan rasa ingin tahu, memeliharanya melalui keandalan serta penghargaan, memperbaikinya melalui pengakuan dan perubahan, serta menumbuhkannya melalui pengalaman dan makna bersama. Empati tidak menghapus suara sendiri; komunikasi asertif menjaga kebutuhan serta batas tanpa merendahkan pribadi lain.

#quote(block: true)[
#strong[Relasi yang sehat tidak menuntut kesempurnaan. Ia membutuhkan kehadiran, kejujuran, kesediaan mendengar, dan keberanian memperbaiki.]
]

Pada bab berikutnya, kita belajar membawa makna yang sama dengan bahasa yang dapat dipahami oleh pribadi dan peran yang berbeda.

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-2>
Pendekatan yang berpusat pada pribadi dan formula Observasi--Perasaan--Kebutuhan--Permintaan dapat didalami melalui #cite(<rogers1961becoming>, form: "prose") dan #cite(<rosenberg2015nonviolent>, form: "prose"). Refleksi tentang kehadiran dalam keluarga bersumber dari perjalanan hidup yang dituturkan dalam #cite(<langi2025dayatarik>, form: "prose").

== Bahasa yang Menjembatani Makna
<bahasa-yang-menjembatani-makna>
#block[
#callout(
body: 
[
#strong[Kalimat dapat benar secara teknis tetapi gagal secara komunikatif. Tugas kita bukan sekadar menunjukkan apa yang kita ketahui, melainkan membantu pribadi tertentu memperoleh makna yang ia perlukan.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-5>
Harta karun bab ini adalah keluwesan bahasa tanpa kehilangan kejujuran. Anda belajar mempertahankan makna inti sambil menyesuaikan istilah, nada, contoh, medium, dan tingkat kerumitan bagi pribadi, peran, relasi, serta tujuan yang berbeda.

Kompetensi ini mulai menjadi milik Anda apabila Anda mampu:

+ membedakan makna dari bentuk bahasa yang membawanya;
+ mengenali ketidakcocokan pengetahuan, peran, tujuan, dan emosi;
+ memilih repertoar yang relevan---penjelasan, contoh, analogi, demonstrasi, visual, data, cerita, pertanyaan, atau simulasi;
+ menerjemahkan satu gagasan untuk lima audiens tanpa mengubah kebenaran inti;
+ memeriksa pemahaman melalui umpan balik; dan
+ menggunakan AI untuk menerjemahkan kompleksitas tanpa kehilangan suara manusia.

=== Tujuan Belajar
<tujuan-belajar-4>
Pada akhir bab ini, Anda mampu:

- menjelaskan hubungan antara pribadi, peran, tujuan, repertoar, bahasa, dan relasi;
- membedakan bahasa teknis, akademik, bisnis, emosional, publik, visual, numerik, dan naratif;
- menggunakan register, metafora, analogi, data, visual, dan cerita secara tepat;
- mengurangi jargon dan ketimpangan pengetahuan;
- melakukan alih ragam bahasa secara autentik dan etis;
- memanfaatkan empat bentuk pesan berdaya tahan dari #emph[Daya Tarik]\;
- menilai hubungan pesan verbal dan nonverbal; serta
- menghasilkan #emph[Portofolio Terjemahan Lima Bahasa].

=== Kata Kunci
<kata-kunci-4>
#strong[Makna], #strong[bahasa], #strong[relevansi], #strong[register], #strong[repertoar], #strong[jargon], #strong[ketimpangan pengetahuan], #strong[alih ragam bahasa (#emph[code-switching])], #strong[analogi], #strong[metafora], #strong[visualisasi], #strong[cerita], #strong[data], #strong[pesan verbal], #strong[pesan nonverbal], #strong[adaptasi etis], dan #strong[suara autentik].

=== Persiapan: "Jadi, Pesanan Saya Bagaimana?"
<persiapan-jadi-pesanan-saya-bagaimana>
Bayangkan seorang mahasiswa informatika berkata kepada pengguna:

#quote(block: true)[
"Aplikasi mengalami #emph[race condition] pada proses asinkron sehingga status transaksi menjadi tidak konsisten."
]

Pengguna menjawab:

#quote(block: true)[
"Jadi, pesanan saya bagaimana?"
]

Jawablah tiga pertanyaan:

+ Apakah pernyataan mahasiswa itu mungkin benar?
+ Makna apa yang sebenarnya dibutuhkan pengguna?
+ Bagaimana Anda akan menjelaskannya tanpa menyembunyikan masalah?

Kegagalan pada contoh ini bukan kurangnya pengetahuan teknis. Justru pengetahuan itu belum diterjemahkan menjadi makna yang relevan.

=== Attention: Dari Nilai Terendah menuju Pidato Penutupan
<attention-dari-nilai-terendah-menuju-pidato-penutupan>
Pada awal 1989, ketika baru menikah, saya mengikuti program persiapan bahasa Inggris di Universitas Gadjah Mada. Program itu mempersiapkan peserta untuk studi ke Kanada. Saya masuk dengan nilai TOEFL terendah dan nyaris tidak diterima.

Di hadapan saya ada banyak kata yang belum dikenal, struktur kalimat yang belum dikuasai, tulisan akademik yang harus diselesaikan, dan keberanian yang perlu dibangun. Saya mencurahkan waktu untuk belajar. Beberapa bulan kemudian, saya memperoleh nilai tertinggi dan dipilih mewakili peserta dari seluruh Indonesia untuk menyampaikan pidato penutupan dalam bahasa Inggris.

Perubahan itu tidak berarti saya menjadi pribadi lain. Saya memperluas repertoar dan memperoleh bahasa baru untuk membawa pikiran saya kepada lingkungan yang lebih luas. Bahasa yang semula menjadi penghalang perlahan menjadi jembatan.

#block[
#callout(
body: 
[
Pengalaman itu membuat saya percaya bahwa bahasa dapat dilatih dan keberanian tumbuh melalui praktik. Kita tidak perlu menunggu sempurna untuk mulai berbicara. Kita perlu menyiapkan makna, mengenali pendengar, mencoba, menerima umpan balik, lalu memperbaiki.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Berbicara Benar Belum Tentu Berkomunikasi Efektif
<interest-berbicara-benar-belum-tentu-berkomunikasi-efektif>
Salah satu jebakan kaum terdidik ialah berkomunikasi untuk memperlihatkan pengetahuan. Kita memilih istilah yang kita kuasai, detail yang menarik bagi kita, dan cara berpikir yang lazim dalam disiplin kita. Tanpa sadar, pesan menjadi pameran pengetahuan, bukan pelayanan makna.

Pertanyaan yang lebih bertanggung jawab bukan:

#quote(block: true)[
"Bagaimana saya memperlihatkan bahwa saya memahami hal ini?"
]

Melainkan:

#quote(block: true)[
#strong["Apa yang perlu dipahami orang ini agar dapat menilai dan bertindak?"]
]

Pemahaman bersama tidak otomatis muncul karena kata telah dikirim. Para pihak perlu membangun landasan bersama dengan memberikan tanda bahwa pesan telah diterima, dipahami, atau masih perlu diperjelas @clark1991grounding. Karena itu, komunikasi tidak selesai pada penjelasan; komunikasi memerlukan pemeriksaan pemahaman.

=== Desire: Makna dan Bahasa
<desire-makna-dan-bahasa>
#strong[Makna] adalah gagasan, kenyataan, pengalaman, atau maksud yang hendak dibawa. #strong[Bahasa] adalah representasi yang digunakan agar makna dapat diterima: kata, angka, gambar, gestur, nada, cerita, atau demonstrasi.

Misalkan makna intinya:

#quote(block: true)[
Sistem saat ini tidak mampu melayani kenaikan jumlah pengguna secara andal.
]

Makna itu dapat dibawa dengan bahasa berbeda:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Pendengar], [Bahasa yang mungkin relevan],),
  table.hline(),
  [Insinyur], ["Pemakaian CPU mencapai 95 persen dan antrean permintaan terus bertambah."],
  [Manajer proyek], ["Kapasitas sistem telah mendekati batas sehingga jadwal peluncuran berisiko."],
  [Pelanggan], ["Layanan dapat melambat ketika banyak orang menggunakannya; kami sedang menambah kapasitas."],
  [Keluarga], ["Komputernya kewalahan karena terlalu banyak orang memakai layanan pada saat yang sama."],
  [Publik], ["Layanan belum cukup andal pada jam sibuk dan perlu diperkuat sebelum digunakan lebih luas."],
)
Kebenaran inti dipertahankan. Istilah, fokus, dan tingkat detail berubah sesuai kebutuhan. Prinsipnya:

#quote(block: true)[
#strong[Jangan mengubah kebenaran agar mudah diterima. Ubahlah cara membawa kebenaran agar dapat dipahami.]
]

=== Bahasa Lebih Luas daripada Bahasa Indonesia atau Inggris
<bahasa-lebih-luas-daripada-bahasa-indonesia-atau-inggris>
Dalam buku ini, bahasa mencakup cara suatu bidang dan komunitas membangun makna.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Ragam bahasa], [Pusat perhatian], [Contoh istilah atau bentuk],),
  table.hline(),
  [Teknis], [Cara kerja dan spesifikasi], [latensi, algoritma, kapasitas],
  [Akademik], [bukti dan ketepatan penalaran], [hipotesis, metode, validitas],
  [Bisnis], [nilai, biaya, risiko, hasil], [investasi, efisiensi, pendapatan],
  [Manajerial], [koordinasi dan tanggung jawab], [target, sumber daya, jadwal],
  [Emosional], [pengalaman dan kebutuhan], [khawatir, dihargai, aman],
  [Publik], [manfaat dan dampak bersama], [keselamatan, keadilan, akses],
  [Visual], [pola dan hubungan], [gambar, diagram, grafik],
  [Numerik], [besaran dan perbandingan], [persentase, peluang, tren],
  [Naratif], [tokoh, tantangan, pilihan, akibat], [kisah, kasus, perjalanan],
)
Bahasa tidak bersifat netral sepenuhnya. Pilihan kita mengarahkan perhatian. Angka "90 persen berhasil" dan "10 persen gagal" dapat merujuk pada data yang sama, tetapi memberikan bingkai yang berbeda. Komunikator bertanggung jawab atas apa yang ditonjolkan dan disembunyikan oleh bingkai tersebut.

=== Relevansi: Jembatan antara Pengetahuan dan Kebutuhan
<relevansi-jembatan-antara-pengetahuan-dan-kebutuhan>
Relevansi bukan menyederhanakan secara sembarangan. Relevansi adalah hubungan antara makna dan kehidupan pendengar. Untuk menemukannya, tanyakan:

- Siapa pribadi yang saya hadapi?
- Dalam peran apa ia sedang mendengarkan?
- Apa yang sudah ia ketahui?
- Apa yang ia butuhkan untuk mengambil keputusan?
- Apa yang ia khawatirkan atau harapkan?
- Tindakan apa yang mungkin perlu ia lakukan?

Seorang dokter yang menjelaskan hasil pemeriksaan kepada sejawat membutuhkan presisi teknis yang berbeda dari ketika menjelaskannya kepada pasien. Namun, pasien tidak boleh kehilangan informasi penting atas nama kesederhanaan. Penyesuaian yang etis membantu pemahaman dan pilihan; penyesuaian manipulatif mengendalikan pilihan dengan menghilangkan konteks yang material.

=== Register dan Alih Ragam Bahasa yang Autentik
<register-dan-alih-ragam-bahasa-yang-autentik>
#strong[Register] adalah ragam bahasa yang sesuai dengan situasi sosial dan bidang. Alih ragam bahasa adalah kemampuan berpindah register tanpa kehilangan makna serta integritas.

Keaslian tidak sama dengan keseragaman. Kita boleh berbicara lebih santai dengan sahabat, lebih terstruktur dalam rapat, dan lebih sederhana kepada publik. Semua versi dapat autentik apabila:

+ fakta inti tidak dipalsukan;
+ nilai kita tidak dijual demi penerimaan;
+ pendengar tidak direndahkan;
+ informasi penting tidak sengaja disembunyikan; dan
+ tujuan adaptasi adalah pemahaman, bukan manipulasi.

=== Jargon dan Ketimpangan Pengetahuan
<jargon-dan-ketimpangan-pengetahuan>
Jargon berguna sebagai singkatan di antara orang yang memiliki latar pengetahuan bersama. Namun, jargon menjadi dinding ketika dipakai kepada orang yang tidak memiliki akses yang sama.

Gunakan tiga langkah "detoks jargon":

+ #strong[Tandai:] lingkari istilah yang hanya dipahami komunitas ahli.
+ #strong[Terjemahkan:] jelaskan dengan kata sehari-hari tanpa menghapus unsur penting.
+ #strong[Uji:] minta seseorang menjelaskan kembali dengan bahasanya sendiri.

Contoh:

- Jargon: "Kita perlu memitigasi risiko #emph[single point of failure]\."
- Terjemahan: "Saat ini, jika satu komponen utama rusak, seluruh layanan berhenti. Kita perlu menyediakan cadangan."

Penyederhanaan yang baik mengurangi beban bahasa, bukan menghilangkan kerumitan kenyataan.

=== Repertoar: Banyak Jalan Menuju Makna
<repertoar-banyak-jalan-menuju-makna>
Ketika penjelasan pertama gagal, jangan hanya mengulangnya dengan suara lebih keras. Gantilah repertoar.

==== Penjelasan dan Contoh
<penjelasan-dan-contoh>
Penjelasan menunjukkan hubungan antargagasan. Contoh membuat gagasan abstrak menjadi konkret. Setelah mendefinisikan "bias data", tunjukkan kasus ketika data pelatihan tidak mewakili kelompok pengguna tertentu.

==== Analogi dan Metafora
<analogi-dan-metafora>
Analogi menghubungkan konsep baru dengan sesuatu yang telah dikenal. Antrean permintaan pada server dapat dianalogikan dengan antrean kendaraan di gerbang tol. Namun, selalu jelaskan batas analogi agar kemiripan tidak dianggap identik.

==== Demonstrasi dan Simulasi
<demonstrasi-dan-simulasi>
Beberapa makna lebih mudah dilihat daripada diceritakan. Tunjukkan prototipe, lakukan percobaan, atau undang pendengar mengalami skenario.

==== Visual dan Data
<visual-dan-data>
Visual membantu melihat struktur, perubahan, dan perbandingan. Data membantu menguji besaran klaim. Keduanya perlu judul, konteks, satuan, sumber, serta penjelasan tentang apa yang boleh dan tidak boleh disimpulkan.

==== Pertanyaan
<pertanyaan>
Pertanyaan mengubah pendengar dari penerima pasif menjadi rekan pembentuk makna. "Bagian mana yang paling berbeda dari pengalaman Anda?" sering lebih berguna daripada "Sudah paham?"

==== Cerita
<cerita>
Cerita menghubungkan gagasan dengan manusia, tantangan, pilihan, dan akibat. Gagasan yang konkret, kredibel, emosional, dan berbentuk cerita cenderung lebih mudah diingat @heath2007made. Namun, cerita tunggal tidak selalu mewakili pola umum; ia perlu ditemani fakta ketika digunakan untuk membuat klaim luas.

=== Empat Pesan Berdaya Tahan
<empat-pesan-berdaya-tahan>
Dalam #emph[Daya Tarik], saya mengajukan empat bentuk pesan yang dapat membuat kehadiran seseorang menarik melampaui penampilan fisik @langi2025dayatarik.

==== Kisah Pengalaman yang Luar Biasa
<kisah-pengalaman-yang-luar-biasa>
Kisah pribadi memberi kesaksian tentang apa yang kita alami, pilih, dan pelajari. Kekuatan utamanya ialah keaslian. Risikonya ialah menjadikan diri pusat segala hal. Ceritakan untuk melayani makna pendengar, bukan sekadar menonjolkan tokoh pencerita.

==== Kisah Inspiratif Berbasis Fakta
<kisah-inspiratif-berbasis-fakta>
Kisah ini menyingkap pola atau misteri melalui fakta. Ia mengundang rasa takjub sekaligus pemeriksaan. Bedakan bagian yang bersumber dari data, bagian yang merupakan interpretasi, dan bagian yang menjadi imajinasi naratif.

==== Konsep yang Mencerdaskan
<konsep-yang-mencerdaskan>
Konsep memberi nama pada pola dan membantu orang melihat banyak peristiwa melalui satu kerangka. Pribadi--Kepribadian--Peran Naratif merupakan contoh. Konsep yang baik mengurangi kebingungan tanpa menyederhanakan manusia secara berlebihan.

==== Opini yang Berpengaruh
<opini-yang-berpengaruh>
Opini menyatakan penilaian atau posisi. Opini menjadi berpengaruh ketika memiliki alasan, bukti, kesadaran akan sudut pandang, serta keterbukaan untuk berubah. Mengubah opini karena informasi baru bukan tanda kelemahan, melainkan tanda bahwa pikiran bekerja.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Bentuk pesan], [Kekuatan utama], [Pertanyaan etik],),
  table.hline(),
  [Kisah pengalaman], [Keaslian dan kedekatan], [Apakah privasi pihak lain terlindungi?],
  [Kisah berbasis fakta], [Rasa ingin tahu dan bukti], [Apakah fakta dibedakan dari dramatisasi?],
  [Konsep], [Kejelasan dan daya jelajah], [Apakah pengecualian dan batasnya dijelaskan?],
  [Opini], [Arah dan pengaruh], [Apakah alasan terbuka untuk diuji?],
)
=== Isi Verbal dan Kemasan Nonverbal
<isi-verbal-dan-kemasan-nonverbal>
Pesan verbal membawa kisah, fakta, konsep, serta opini. Pesan nonverbal---tatapan, postur, intonasi, jeda, ekspresi, pakaian, tata ruang, dan mutu visual---membentuk cara isi itu dialami. Dalam #emph[Daya Tarik], pesan verbal diperlakukan sebagai isi yang dapat bertahan lama, sedangkan aspek nonverbal menjadi kemasan penting @langi2025dayatarik.

Kemasan tidak boleh menutupi isi yang lemah atau menipu. Slide indah tidak memperbaiki data palsu. Nada hangat tidak membenarkan manipulasi. Sebaliknya, isi yang baik perlu kemasan yang memungkinkan orang mengaksesnya: suara cukup jelas, visual terbaca, tempo memberi waktu berpikir, dan medium dapat digunakan oleh audiens.

=== Empat Ketidakcocokan Bahasa
<empat-ketidakcocokan-bahasa>
+ #strong[Ketidakcocokan pengetahuan:] istilah dan prasyarat terlalu tinggi atau terlalu rendah.
+ #strong[Ketidakcocokan peran:] bahasa yang sesuai bagi ahli dipakai kepada pelanggan, atau bahasa santai dipakai dalam tanggung jawab formal yang menuntut presisi.
+ #strong[Ketidakcocokan tujuan:] penjelasan panjang diberikan ketika orang membutuhkan keputusan singkat; ajakan bertindak diberikan sebelum orang memahami masalah.
+ #strong[Ketidakcocokan emosi:] data diberikan ketika orang sedang membutuhkan pengakuan atas kekhawatiran; humor digunakan ketika situasi menuntut kesungguhan.

Diagnosis ketidakcocokan membantu kita memperbaiki komunikasi tanpa menyalahkan kecerdasan pendengar.

=== Dengarkan sebelum Menerjemahkan
<dengarkan-sebelum-menerjemahkan>
Penyesuaian yang baik dimulai dari mendengar. Jangan berasumsi bahwa semua anak membutuhkan bahasa kekanak-kanakan atau semua manajer hanya peduli uang. Tanyakan:

- "Apa yang sudah Anda ketahui tentang hal ini?"
- "Bagian mana yang paling penting bagi keputusan Anda?"
- "Apakah Anda ingin gambaran umum atau rincian teknis?"
- "Bolehkah saya menggunakan contoh?"

Sesudah menjelaskan, hindari pertanyaan ya/tidak "Paham?" Gunakan pemeriksaan yang tidak mempermalukan:

#quote(block: true)[
"Agar saya tahu apakah penjelasan saya cukup jelas, bolehkah Anda menceritakan kembali langkah yang akan kita lakukan?"
]

Jika pemahaman belum terbentuk, tanggung jawab pertama komunikator ialah mencoba representasi lain.

=== AI sebagai Penerjemah Kompleksitas
<ai-sebagai-penerjemah-kompleksitas>
AI dapat membantu membuat beberapa versi, mendeteksi jargon, mengubah format, atau melakukan simulasi audiens. Gunakan perintah yang mempertahankan kendali manusia:

#quote(block: true)[
"Pertahankan tiga fakta inti berikut. Buat versi untuk pembaca umum berusia sekitar 18 tahun. Jelaskan istilah teknis ketika pertama muncul, jangan menghilangkan risiko, tandai bagian yang masih memerlukan verifikasi, dan pertahankan nada saya yang tenang."
]

Kemudian periksa:

+ Apakah fakta inti tetap utuh?
+ Apakah ada informasi penting yang hilang?
+ Apakah contoh akurat dan sesuai budaya?
+ Apakah bahasa terdengar seperti suara saya?
+ Apakah data pribadi atau rahasia telah terlindungi?

AI tidak otomatis mengenal pribadi yang dituju. Ia dapat menghasilkan bahasa yang lancar tetapi tidak relevan, terlalu pasti, atau mengandung kekeliruan. Anda tetap menjadi penulis, pemeriksa, dan penanggung jawab.

=== Praktis: Satu Makna, Lima Bahasa
<praktis-satu-makna-lima-bahasa>
Pilih satu gagasan dari bidang studi Anda. Rumuskan #strong[makna inti] dalam satu atau dua kalimat yang tidak boleh berubah. Kemudian jelaskan kepada:

+ seorang anak berusia sekitar 10 tahun;
+ seorang sahabat dari bidang lain;
+ seorang rekan teknis;
+ seorang manajer atau pengambil keputusan; dan
+ publik umum.

#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header([Audiens], [Kebutuhan utama], [Ragam bahasa], [Repertoar], [Versi ringkas],),
  table.hline(),
  [Anak], [], [], [], [],
  [Sahabat], [], [], [], [],
  [Rekan teknis], [], [], [], [],
  [Manajer], [], [], [], [],
  [Publik], [], [], [], [],
)
Mintalah mitra membaca setiap versi dan menuliskan kembali makna yang ia tangkap. Perbedaan antara makna yang Anda maksud dan makna yang ia tangkap adalah data perbaikan.

=== Perform: Portofolio Terjemahan Lima Bahasa
<perform-portofolio-terjemahan-lima-bahasa>
Kembangkan latihan di atas menjadi portofolio yang memuat:

- konteks dan pentingnya gagasan;
- profil singkat kelima audiens tanpa stereotip;
- makna inti yang konsisten;
- lima versi masing-masing 100--180 kata atau padanan visual/audio;
- alasan pemilihan register dan repertoar;
- bukti uji pemahaman dari sedikitnya dua orang;
- catatan penggunaan AI, jika ada, termasuk bagian yang ditolak atau diperbaiki; dan
- refleksi tentang kejujuran, relevansi, serta suara autentik.

==== Rubrik Kinerja
<rubrik-kinerja-3>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Kriteria], [Belum tampak], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Keteguhan makna inti], [Makna berubah antarversi], [Ada pergeseran kecil], [Fakta dan maksud inti konsisten],
  [Relevansi bagi audiens], [Berdasarkan stereotip], [Ada penyesuaian umum], [Berdasarkan kebutuhan, peran, dan tujuan],
  [Pilihan bahasa dan repertoar], [Jargon atau satu bentuk], [Beberapa bentuk digunakan], [Bentuk beragam dan tepat guna],
  [Kejelasan dan aksesibilitas], [Sulit diikuti], [Umumnya dapat dipahami], [Ringkas, terstruktur, dan mudah diuji],
  [Etika dan keaslian], [Informasi penting hilang], [Etika disebut tetapi belum konsisten], [Jujur, tidak manipulatif, suara penulis terjaga],
  [Umpan balik], [Tidak diuji], [Uji terbatas], [Umpan balik dipakai untuk revisi],
)
=== Refleksi
<refleksi-4>
+ Apakah saya lebih sering berkomunikasi untuk menunjukkan pengetahuan atau melayani pemahaman?
+ Jargon apa yang paling sering saya gunakan tanpa sadar?
+ Repertoar apa yang paling saya kuasai? Mana yang perlu dilatih?
+ Kapan penyesuaian bahasa berubah menjadi manipulasi?
+ Bagaimana saya mengetahui bahwa makna yang diterima cukup dekat dengan makna yang saya maksud?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-5>
Makna dan bahasa perlu dibedakan. Makna inti dapat tetap sama sementara istilah, nada, contoh, medium, dan tingkat detail menyesuaikan pribadi, peran, relasi, serta tujuan. Relevansi ditemukan dengan mendengarkan. Jargon perlu diterjemahkan; repertoar perlu diperluas; pemahaman perlu diperiksa. Kisah, fakta, konsep, dan opini dapat membawa pesan yang berdaya tahan, sementara kemasan nonverbal membantu orang mengakses isinya.

#quote(block: true)[
#strong[Komunikator yang matang tidak mengubah kebenaran untuk menyenangkan pendengar. Ia mencari bahasa yang membuat kebenaran dapat dipahami dan dipertanggungjawabkan.]
]

Dengan bab ini, fondasi Bagian I selesai. Kita telah belajar melihat pribadi, mendengar percakapan batin, menghadirkan relasi terdekat, dan menjembatani makna. Bagian II akan membawa fondasi ini ke dunia kerja, pelanggan, kesepakatan, dan tindakan bersama.

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-3>
Pembahasan mengenai pembentukan pemahaman bersama, gagasan yang mudah diingat, serta repertoar pesan verbal dan nonverbal dapat didalami melalui #cite(<clark1991grounding>, form: "prose"), #cite(<heath2007made>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

#heading(level: 1, numbering: none)[Bagian II --- Mengubah Komunikasi Menjadi Nilai dan Tindakan]
<bagian-ii-mengubah-komunikasi-menjadi-nilai-dan-tindakan-1>
== Rekan Kerja dan Pelanggan: Menciptakan Nilai Bersama
<rekan-kerja-dan-pelanggan-menciptakan-nilai-bersama>
#block[
#callout(
body: 
[
#strong[Produk yang canggih belum tentu bernilai. Nilai lahir ketika pengetahuan, pekerjaan, dan layanan sungguh-sungguh menjawab persoalan manusia.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-6>
Harta karun bab ini adalah kemampuan melakukan percakapan profesional untuk menemukan masalah, memahami kebutuhan, mengoordinasikan pekerjaan, dan merumuskan nilai bersama. Anda berhasil apabila dapat menahan dorongan menawarkan solusi terlalu dini dan menghasilkan rumusan masalah yang diakui oleh pihak terkait.

=== Tujuan Belajar
<tujuan-belajar-5>
Pada akhir bab ini, Anda mampu:

- membedakan pribadi dari peran profesionalnya;
- menjelaskan nilai sebagai hasil yang relevan bagi pengguna atau penerima manfaat;
- melakukan wawancara penemuan kebutuhan;
- membedakan masalah, kebutuhan, permintaan, dan solusi;
- membangun kepercayaan melalui kompetensi, integritas, keandalan, kepedulian, dan tanggung jawab; serta
- menyusun #emph[Pernyataan Masalah Pelanggan] yang terkonfirmasi.

=== Kata Kunci
<kata-kunci-5>
#strong[Relasi profesional], #strong[rekan kerja], #strong[pelanggan], #strong[nilai bersama], #strong[penemuan masalah], #strong[kebutuhan], #strong[kendala], #strong[hasil yang diharapkan], #strong[kepercayaan profesional], dan #strong[pernyataan masalah].

=== Persiapan: Solusi yang Belum Diminta
<persiapan-solusi-yang-belum-diminta>
Ingat satu pengalaman ketika seseorang segera memberi solusi sebelum memahami persoalan Anda. Apa yang membuat respons itu tidak membantu? Kemudian ingat saat seseorang mengajukan pertanyaan yang tepat. Apa yang berubah?

=== Attention: Menjadi Dosen Muda
<attention-menjadi-dosen-muda>
Setelah lulus Teknik Elektro ITB pada 1987, saya sempat mengikuti teman-teman melamar ke berbagai perusahaan. Namun, impian studi lanjut membawa saya memilih menjadi dosen ITB. Pada April 1988 saya bergabung dengan PAU Mikroelektronika di bawah Dr.~Richard Mengko. Prof.~Samaun sedang membangun pusat itu dan mempersiapkan staf untuk belajar ke luar negeri.

Saya datang bukan sebagai orang yang telah mengetahui semuanya. Saya hadir sebagai dosen muda, anggota tim, pembelajar, dan calon peneliti. Ada misi lembaga, arahan mentor, persyaratan beasiswa, serta pekerjaan yang harus diselesaikan bersama. Pilihan profesional itu membuka kesempatan karena kebutuhan pribadi saya---bertumbuh dan studi lanjut---bertemu dengan kebutuhan lembaga untuk mengembangkan kompetensi.

#block[
#callout(
body: 
[
Karier tidak hanya dibangun dengan bertanya, "Apa yang dapat saya peroleh?" Pertanyaan yang lebih subur ialah, "Masalah apa yang penting, nilai apa yang dapat saya sumbangkan, dan bersama siapa saya perlu belajar?"

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Pekerjaan adalah Sistem Relasi
<interest-pekerjaan-adalah-sistem-relasi>
Organisasi tidak berisi dua jenis manusia bernama "pegawai" dan "pelanggan". Ia berisi pribadi-pribadi yang sedang menjalankan peran. Orang yang hari ini melayani pelanggan besok menjadi pelanggan layanan lain. Seorang ahli dapat menjadi pemimpin, pemasok, pengguna, atau anggota masyarakat terdampak.

Peran profesional membawa misi dan tanggung jawab:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Peran], [Tanggung jawab komunikasi],),
  table.hline(),
  [Rekan kerja], [berbagi informasi, menepati komitmen, dan membantu koordinasi],
  [Anggota tim], [menyumbang keahlian serta meminta bantuan ketika diperlukan],
  [Pemimpin], [memperjelas arah, menyediakan dukungan, dan menjaga akuntabilitas],
  [Spesialis], [menerjemahkan pengetahuan menjadi keputusan yang dapat dipahami],
  [Pelanggan/pengguna], [menjelaskan kebutuhan, pengalaman, dan batas penerimaan],
  [Pemasok/mitra], [menyatakan kemampuan, syarat, risiko, dan ketergantungan],
)
Relasi profesional berbeda dari persahabatan karena dibentuk oleh misi, kewenangan, standar, dan pertukaran nilai. Namun, ia tetap berlangsung antarmanusia. Profesionalisme bukan menjadi dingin; profesionalisme ialah kepedulian yang dapat diandalkan.

=== Desire: Nilai Ada dalam Pengalaman Penerima
<desire-nilai-ada-dalam-pengalaman-penerima>
Sebuah fitur belum menjadi nilai hanya karena sulit dibuat. Nilai muncul ketika sumber daya atau layanan membantu seseorang mencapai hasil yang penting. Perspektif ini sejalan dengan pandangan bahwa nilai dibentuk bersama dalam penggunaan, bukan sekadar ditanamkan oleh produsen @vargo2004evolving.

Peter Drucker mengingatkan bahwa organisasi perlu melihat keluar kepada orang yang dilayaninya @drucker1954practice. Karena itu, ubahlah pertanyaan:

#quote(block: true)[
"Apa yang dapat saya bangun?"
]

menjadi:

#quote(block: true)[
#strong["Masalah apa yang penting bagi seseorang, dan hasil lebih baik apa yang ingin ia capai?"]
]

==== Masalah, Kebutuhan, Permintaan, dan Solusi
<masalah-kebutuhan-permintaan-dan-solusi>
- #strong[Masalah:] kesenjangan antara keadaan sekarang dan keadaan yang dianggap lebih baik.
- #strong[Kebutuhan:] sesuatu yang diperlukan untuk mengurangi kesenjangan itu.
- #strong[Permintaan:] bentuk bantuan yang dinyatakan oleh seseorang.
- #strong[Solusi:] cara tertentu yang diusulkan untuk memenuhi kebutuhan.

Permintaan belum tentu merupakan solusi terbaik. Ketika seseorang meminta "aplikasi baru", kebutuhannya mungkin akses informasi yang lebih cepat. Solusinya dapat berupa perbaikan proses, bukan aplikasi.

=== Mendengarkan sebelum Menjelaskan
<mendengarkan-sebelum-menjelaskan>
Penemuan kebutuhan membutuhkan kerendahan hati untuk bertanya karena kita belum mengetahui jawaban @schein2013humble. Gunakan lima pertanyaan:

+ #strong[Apa yang sedang terjadi?] Minta contoh konkret.
+ #strong[Mengapa hal itu menjadi masalah?] Temukan dampaknya.
+ #strong[Siapa yang terdampak?] Kenali pribadi dan perannya.
+ #strong[Keadaan yang lebih baik seperti apa?] Rumuskan hasil, bukan fitur.
+ #strong[Apa kendalanya?] Periksa waktu, biaya, kebijakan, kemampuan, dan risiko.

Parafrasakan jawaban dan minta koreksi. Rasio mendengarkan sebaiknya lebih besar daripada menjelaskan selama tahap penemuan.

=== Merumuskan Masalah Bersama
<merumuskan-masalah-bersama>
Gunakan pola:

#quote(block: true)[
#strong[\[Pribadi/peran\] mengalami \[keadaan yang dapat diamati\] ketika \[konteks\], sehingga \[dampak\]. Ia membutuhkan \[hasil/kemampuan\], dengan mempertimbangkan \[kendala\].]
]

Contoh:

#quote(block: true)[
Mahasiswa pengguna kantin mengalami antrean yang tidak dapat diperkirakan pada jam pergantian kuliah sehingga terlambat masuk kelas. Mereka membutuhkan cara mengetahui waktu tunggu dan mengambil pesanan lebih cepat, dengan mempertimbangkan kemampuan kasir, biaya pemilik, serta akses pengguna tanpa telepon pintar.
]

Pernyataan ini belum mengunci solusi. Ia menjadi landasan bersama untuk menjelajahi pilihan.

=== Kepercayaan Profesional
<kepercayaan-profesional>
Kepercayaan bertumbuh ketika orang melihat:

- #strong[kompetensi:] kita mampu atau mau belajar;
- #strong[keandalan:] ucapan dan tindakan konsisten;
- #strong[kejujuran:] ketidakpastian serta batas disampaikan;
- #strong[kepedulian:] dampak pada manusia diperhitungkan;
- #strong[akuntabilitas:] kesalahan diakui dan diperbaiki.

Mengatakan "Saya belum tahu; saya akan memeriksa dan kembali besok pukul 10.00" lebih dapat dipercaya daripada jawaban lancar yang tidak akurat. Keamanan psikologis juga penting agar anggota tim dapat bertanya, mengakui kesalahan, dan menyampaikan risiko @edmondson1999psychological.

=== Dari Menyalahkan Orang menuju Menyelesaikan Masalah
<dari-menyalahkan-orang-menuju-menyelesaikan-masalah>
Tekanan kerja mudah mengubah bahasa masalah menjadi bahasa karakter.

- Menyalahkan: "Tim data memang tidak pernah serius."
- Berpusat pada masalah: "Dua variabel yang dibutuhkan belum tersedia sehingga analisis tertunda tiga hari."

Bahasa kedua tidak meniadakan tanggung jawab. Justru ia membuat tanggung jawab dapat dibicarakan: data apa yang hilang, siapa yang dapat menyediakannya, dukungan apa yang diperlukan, dan kapan pekerjaan dapat dilanjutkan. Kritik terhadap proses lebih mungkin menghasilkan perbaikan daripada label terhadap pribadi.

=== Repertoar Pertanyaan Profesional
<repertoar-pertanyaan-profesional>
Gunakan pertanyaan sesuai kebutuhan:

- #strong[tertutup:] memastikan fakta---"Apakah laporan dikirim kemarin?";
- #strong[terbuka:] menjelajahi pengalaman---"Apa yang membuat proses ini sulit?";
- #strong[klarifikasi:] memeriksa istilah---"Apa yang dimaksud 'siap'?";
- #strong[dampak:] memahami akibat---"Siapa yang terhambat jika data terlambat?";
- #strong[masa depan:] merumuskan hasil---"Keadaan yang lebih baik terlihat seperti apa?"

Pertanyaan bertubi-tubi dapat terasa seperti interogasi. Selang-selingkan pertanyaan dengan parafrasa, pengakuan, dan keheningan. Percakapan penemuan bukan daftar yang harus dihabiskan, melainkan perjumpaan yang perlu diikuti.

=== AI dalam Penemuan Profesional
<ai-dalam-penemuan-profesional>
AI dapat membantu menyusun pertanyaan, mensimulasikan wawancara, mengelompokkan catatan, atau memeriksa asumsi. Jangan memasukkan data rahasia atau membiarkan AI membuat profil psikologis pelanggan. Ringkasan AI harus dikonfirmasi kepada manusia yang diwawancarai.

=== Praktis: Wawancara Penemuan Kebutuhan
<praktis-wawancara-penemuan-kebutuhan>
Bekerjalah berpasangan. Pewawancara memilih satu persoalan kampus. Selama delapan menit:

+ minta satu contoh peristiwa;
+ gunakan lima pertanyaan penemuan;
+ jangan menawarkan solusi selama enam menit pertama;
+ parafrasa dua kali; dan
+ minta persetujuan atas rumusan masalah.

Pengamat mencatat pertanyaan terbuka, asumsi, jargon, dan momen ketika pewawancara melompat ke solusi.

=== Perform: Pernyataan Masalah Pelanggan
<perform-pernyataan-masalah-pelanggan>
Lakukan satu wawancara nyata yang etis selama 15--20 menit. Serahkan:

- profil peran tanpa data pribadi yang tidak perlu;
- asumsi awal;
- lima pertanyaan dan ringkasan jawaban;
- pernyataan masalah sebelum dan sesudah konfirmasi;
- kutipan singkat dengan izin atau parafrasa;
- kendala dan hal yang belum diketahui; serta
- refleksi tentang perubahan pemahaman dan relasi.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Kualitas mendengarkan], [Menangkap isi umum], [Menangkap konteks, dampak, kebutuhan, dan kendala],
  [Rumusan masalah], [Masih berupa solusi], [Berpusat pada pribadi, teramati, dan terkonfirmasi],
  [Kepercayaan], [Janji atau kepastian berlebihan], [Jujur terhadap batas dan tindak lanjut jelas],
  [Etika], [Data dikumpulkan berlebihan], [Persetujuan, privasi, dan martabat terjaga],
)
=== Refleksi
<refleksi-5>
+ Seberapa cepat saya biasanya menawarkan solusi?
+ Asumsi apa yang berubah setelah mendengarkan?
+ Apakah pihak lain mengakui rumusan masalah sebagai miliknya?
+ Nilai bersama apa yang mungkin diciptakan?
+ Janji kecil apa yang perlu saya tepati untuk membangun kepercayaan?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-6>
Pekerjaan adalah sistem relasi tempat pribadi-pribadi menjalankan peran dan misi. Nilai tidak sama dengan fitur; nilai adalah hasil yang relevan bagi penerima. Karena itu, komunikator profesional mendengarkan sebelum mengusulkan, membedakan masalah dari solusi, merumuskan kebutuhan bersama, dan membangun kepercayaan melalui kompetensi, integritas, keandalan, kepedulian, serta tanggung jawab.

#quote(block: true)[
#strong[Jangan mulai dari apa yang ingin Anda jual atau bangun. Mulailah dari manusia, masalah yang penting baginya, dan keadaan lebih baik yang ingin diwujudkan bersama.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-4>
Lihat #cite(<drucker1954practice>, form: "prose"), #cite(<vargo2004evolving>, form: "prose"), #cite(<schein2013humble>, form: "prose"), #cite(<edmondson1999psychological>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== TAIDA I: Menemukan Sasaran dan Memperoleh Perhatian
<taida-i-menemukan-sasaran-dan-memperoleh-perhatian>
#block[
#callout(
body: 
[
#strong[Perhatian bukan hak komunikator. Perhatian perlu diperoleh dengan menunjukkan bahwa suatu masalah atau peluang sungguh relevan bagi pribadi yang dihadapi.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-7>
Harta karun bab ini adalah kemampuan memilih pribadi yang tepat, membaca konteksnya, dan membuat masalah atau peluang terlihat tanpa mengganggu, mempermalukan, atau menakut-nakuti. Bukti keberhasilannya ialah munculnya respons yang menunjukkan, "Ya, hal ini relevan bagi saya."

=== Tujuan Belajar
<tujuan-belajar-6>
Anda mampu memetakan pemangku kepentingan, membedakan sasaran dari kategori, membedakan perhatian dari interupsi, menyusun #emph[pitch] Sasaran--Perhatian, membaca respons verbal dan nonverbal, serta menyesuaikan langkah berdasarkan keadaan komunikasi.

=== Kata Kunci
<kata-kunci-6>
#strong[TAIDA], #strong[sasaran], #strong[perhatian], #strong[pemangku kepentingan], #strong[konteks], #strong[relevansi], #strong[observasi], #strong[dampak], #strong[interupsi], #strong[keadaan komunikasi], dan #strong[umpan balik tertutup].

=== Persiapan: Siapa yang Sebenarnya Perlu Mendengar?
<persiapan-siapa-yang-sebenarnya-perlu-mendengar>
Pilih satu persoalan kampus. Tuliskan semua pihak yang mengalami, mengerjakan, membiayai, memutuskan, atau terdampak. Lingkari satu pihak yang paling tepat untuk percakapan pertama. Mengapa bukan pihak lainnya?

=== Attention: Kartu Pos yang Memperoleh Perhatian
<attention-kartu-pos-yang-memperoleh-perhatian>
Kartu pos Golden Gate yang saya terima ketika kelas dua sekolah dasar tidak berteriak, tidak memberi ancaman, dan tidak memuat penjelasan panjang. Gambar itu relevan bagi rasa ingin tahu seorang anak di Tomohon. Ia membuat dunia yang jauh menjadi terlihat dan menumbuhkan perhatian yang bertahan bertahun-tahun.

Dalam #emph[Daya Tarik], pesan yang mengesankan dipahami sebagai isi yang membuat orang melihat kemungkinan, konsep, atau pengalaman yang berarti @langi2025dayatarik. Pelajarannya bukan bahwa semua pembuka harus dramatis. Pembuka perlu menemukan hubungan antara kenyataan dan kehidupan orang yang dituju.

=== Interest: TAIDA sebagai Perubahan Keadaan
<interest-taida-sebagai-perubahan-keadaan>
TAIDA memetakan perjalanan:

#quote(block: true)[
#strong[Target (Sasaran) → Attention (Perhatian) → Interest (Minat) → Desire (Keinginan) → Action (Tindakan)]
]

Tahap bukan sekadar urutan kalimat, melainkan keadaan pihak lain. Kita tidak boleh bergerak hanya karena naskah telah selesai dibacakan. Kita bergerak ketika respons menunjukkan keadaan telah berubah.

==== Sasaran adalah Pribadi, Bukan Segmen
<sasaran-adalah-pribadi-bukan-segmen>
Kategori "mahasiswa" terlalu luas. Mahasiswa pengguna kantin, bendahara organisasi, mahasiswa yang memiliki alergi makanan, dan mahasiswa tanpa akses pembayaran digital menjalankan peran serta kebutuhan berbeda.

Peta sasaran memuat:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Unsur], [Pertanyaan],),
  table.hline(),
  [Pribadi/peran], [Siapa yang mengalami atau memengaruhi persoalan?],
  [Tujuan], [Apa yang penting baginya?],
  [Konteks], [Kapan dan di mana persoalan terjadi?],
  [Riwayat relasi], [Apa pengalaman sebelumnya dengan kita?],
  [Wewenang], [Apa yang dapat ia putuskan atau lakukan?],
  [Keadaan TAIDA], [Belum sadar, memperhatikan, berminat, menginginkan, atau siap bertindak?],
)
Target yang salah menghasilkan percakapan yang tidak bergerak. Orang yang merasakan masalah belum tentu memiliki wewenang, dan orang yang berwenang belum tentu melihat dampaknya.

==== Perhatian Bukan Interupsi
<perhatian-bukan-interupsi>
Interupsi merebut fokus. Perhatian yang etis menunjukkan relevansi dan memberi kebebasan untuk melanjutkan atau berhenti.

- Sensasional: "Sistem kita dalam bahaya besar!"
- Berpusat pada pribadi: "Dalam dua minggu terakhir, tiga laporan terlambat karena data harus dimasukkan ulang. Apakah hal ini juga menghambat tim Anda?"

Pembuka kedua memiliki observasi, dampak, dan pemeriksaan. Ia dapat diuji dan mengundang tanggapan.

=== Desire: Formula Pitch Perhatian
<desire-formula-pitch-perhatian>
==== Versi Masalah
<versi-masalah>
#quote(block: true)[
#strong[Observasi → Dampak → Periksa]
]

+ #strong[Observasi:] "Saya mengamati rata-rata antrean mencapai 18 menit pada pukul 12.00."
+ #strong[Dampak:] "Sebagian mahasiswa kembali terlambat ke kelas."
+ #strong[Periksa:] "Apakah ini juga persoalan yang ingin Bapak/Ibu kurangi?"

==== Versi Peluang
<versi-peluang>
#quote(block: true)[
#strong[Keadaan sekarang → Kemungkinan → Periksa]
]

#quote(block: true)[
"Sebagian besar pesanan sudah berulang setiap minggu. Ada kemungkinan mempercepat layanan dengan persiapan sebelumnya. Apakah peluang ini layak kita telusuri?"
]

Perhatian dapat diperoleh melalui observasi, data, perbandingan, cerita singkat, pertanyaan, atau demonstrasi. Pilih bukti yang proporsional. Jangan memakai satu anekdot untuk mengklaim pola umum.

=== Membaca Apakah Perhatian Telah Diperoleh
<membaca-apakah-perhatian-telah-diperoleh>
Isyarat verbal:

- "Benar, kami juga melihatnya."
- "Data itu dari periode mana?"
- "Saya belum yakin itu masalah utama."

Isyarat nonverbal dapat berupa tatapan, perubahan postur, jeda, atau kembali melihat pekerjaan. Namun, isyarat nonverbal ambigu. Jangan membaca pikiran; periksa dengan pertanyaan.

Gunakan komunikasi lingkar tertutup:

#quote(block: true)[
sampaikan → amati respons → periksa pemahaman → sesuaikan.
]

Jika perhatian belum diperoleh, pilih antara memperbaiki bukti, mengganti bahasa, mencari pihak yang lebih tepat, atau menghentikan percakapan dengan hormat.

=== Enam Jalan Memperoleh Perhatian
<enam-jalan-memperoleh-perhatian>
Pilih jalan yang paling sesuai dengan pribadi dan situasi.

+ #strong[Observasi:] tunjukkan pola yang dapat dilihat.
+ #strong[Data:] berikan besaran dan konteks pembanding.
+ #strong[Perbandingan:] tunjukkan perubahan waktu atau perbedaan kondisi.
+ #strong[Cerita singkat:] hadirkan pengalaman satu pribadi tanpa menggeneralisasi.
+ #strong[Pertanyaan:] undang pihak lain memeriksa pengalamannya.
+ #strong[Demonstrasi:] buat masalah atau peluang dapat dialami langsung.

Sebuah data dapat akurat tetapi tidak memperoleh perhatian apabila pendengar tidak memahami maknanya. Sebaliknya, cerita dapat menarik perhatian tetapi perlu dilengkapi data sebelum dipakai untuk klaim yang luas. Isi dan kemasan perlu saling mendukung.

=== Kegagalan yang Sering Terjadi
<kegagalan-yang-sering-terjadi>
- #strong[Latar belakang terlalu panjang:] inti relevansi tenggelam.
- #strong[Melompat ke solusi:] pihak lain belum mengakui masalah.
- #strong[Menyerang:] perhatian diperoleh melalui pertahanan diri.
- #strong[Bukti lemah:] klaim lebih besar daripada data.
- #strong[Salah pihak:] orang yang diajak bicara tidak mengalami atau tidak berwenang.
- #strong[Tanpa pemeriksaan:] komunikator mengira diam berarti setuju.

Perbaikan tidak selalu berarti membuat pitch lebih menarik. Kadang perbaikan berarti mengakui bahwa masalah belum cukup dipahami.

=== Etika Perhatian
<etika-perhatian>
Jangan menyerang pribadi, mengeksploitasi ketakutan, menyembunyikan identitas komersial, atau membuat urgensi palsu. "Tidak" merupakan informasi dan hak. TAIDA bukan corong manipulasi; ia adalah peta untuk menemani pilihan yang sadar.

=== AI sebagai Asisten Pemetaan
<ai-sebagai-asisten-pemetaan>
AI dapat membantu menghasilkan daftar pihak, meninjau jargon, dan mencoba beberapa pembuka. Hasilnya perlu diperiksa oleh orang yang memahami konteks. Hindari profil manipulatif berdasarkan data pribadi, emosi, atau kerentanan.

=== Praktis: Tiga Pitch untuk Tiga Pihak
<praktis-tiga-pitch-untuk-tiga-pihak>
Gunakan satu persoalan kampus. Susun tiga pembuka untuk tiga peran berbeda. Masing-masing maksimal 45 kata dan harus memuat bukti serta pertanyaan pemeriksaan.

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([Pihak], [Hal yang relevan], [Bukti], [Pitch perhatian],),
  table.hline(),
  [Pengguna], [], [], [],
  [Pelaksana], [], [], [],
  [Pengambil keputusan], [], [], [],
)
Uji kepada rekan. Mintalah mereka menandai apakah pembuka terasa relevan, berlebihan, menghakimi, atau terlalu panjang.

=== Perform: Tantangan Sasaran--Perhatian
<perform-tantangan-sasaranperhatian>
Lakukan percakapan 90 detik:

+ minta izin singkat;
+ sampaikan observasi atau peluang;
+ jelaskan satu dampak;
+ periksa relevansi;
+ dengarkan; dan
+ nyatakan keadaan setelah percakapan.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Ketepatan sasaran], [Berdasarkan kategori], [Berdasarkan peran, konteks, dan wewenang],
  [Kualitas pembuka], [Sensasional atau panjang], [Ringkas, berbukti, dan relevan],
  [Respons], [Diabaikan], [Dibaca dan dipakai untuk menyesuaikan],
  [Etika], [Menekan], [Memberi kebebasan dan menjaga relasi],
)
=== Refleksi
<refleksi-6>
+ Apakah saya berbicara kepada orang yang tepat?
+ Bukti apa yang cukup untuk membuat persoalan terlihat?
+ Apakah saya memperoleh perhatian atau hanya menginterupsi?
+ Apa tanda bahwa pihak lain menganggapnya relevan?
+ Bagaimana keadaan relasi setelah pembuka?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-7>
Sasaran adalah pribadi dalam peran dan konteks tertentu. Perhatian diperoleh ketika masalah atau peluang dibuat terlihat secara relevan, proporsional, dan etis. Pitch yang baik menghubungkan observasi dengan dampak lalu memeriksa tanggapan. Respons menentukan apakah kita bergerak, menyesuaikan, atau berhenti.

#quote(block: true)[
#strong[Perhatian yang sehat tidak dirampas; ia dipercayakan karena orang melihat bahwa kita memahami sesuatu yang penting baginya.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-5>
Lihat #cite(<heath2007made>, form: "prose"), #cite(<schein2013humble>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== TAIDA II: Menumbuhkan Minat
<taida-ii-menumbuhkan-minat>
#block[
#callout(
body: 
[
#strong[Orang jarang tertarik pada kecanggihan solusi sebelum melihat hubungannya dengan persoalan yang sungguh mereka alami.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-8>
Harta karun bab ini adalah kemampuan menghubungkan masalah yang telah diakui dengan kemungkinan solusi yang relevan. Keberhasilan bukan diukur dari panjangnya penjelasan, melainkan dari respons: pihak lain ingin mengetahui lebih jauh dan mulai menguji kecocokan solusi.

=== Tujuan Belajar
<tujuan-belajar-7>
Anda mampu membedakan perhatian dan minat, memetakan kecocokan masalah--solusi, mengubah fitur menjadi manfaat serta nilai, menggunakan kisah, pertanyaan, konsep, analogi, atau prototipe, dan menyampaikan #emph[pitch] masalah--solusi selama 60 detik.

=== Kata Kunci
<kata-kunci-7>
#strong[Minat], #strong[kecocokan masalah--solusi], #strong[fitur], #strong[manfaat], #strong[nilai], #strong[rasa ingin tahu], #strong[prototipe], #strong[komunikasi berlapis], #strong[kredibilitas], dan #strong[pitch masalah--solusi].

=== Persiapan: Ketika Penjelasan Terlalu Cepat
<persiapan-ketika-penjelasan-terlalu-cepat>
Pilih satu teknologi atau gagasan yang Anda sukai. Jelaskan dalam satu kalimat tanpa menyebut nama teknologi, fitur, atau istilah teknis. Anda hanya boleh menyatakan masalah yang dibantu dan hasil awal yang mungkin diperoleh.

=== Attention: Dari "Itu Masalah" menuju "Bagaimana Caranya?"
<attention-dari-itu-masalah-menuju-bagaimana-caranya>
Bayangkan pengelola kantin telah mengakui antrean panjang sebagai persoalan. Jika kita segera menjelaskan arsitektur aplikasi, basis data, dan integrasi pembayaran, perhatian dapat hilang. Pengelola belum meminta kuliah teknologi. Ia sedang mencari hubungan antara persoalan dan kemungkinan keadaan yang lebih baik.

Pertanyaan yang menandai minat biasanya berbunyi:

- "Bagaimana cara kerjanya?"
- "Apakah ini dapat dipakai dengan proses kami?"
- "Apa bedanya dari yang pernah dicoba?"
- "Bisakah saya melihat contohnya?"

=== Interest: Perhatian Tidak Sama dengan Minat
<interest-perhatian-tidak-sama-dengan-minat>
Pada tahap perhatian, orang mengakui relevansi masalah atau peluang. Pada tahap minat, ia menganggap kemungkinan solusi layak dijelajahi.

#quote(block: true)[
#strong[Masalah yang diakui + kemungkinan yang relevan + mekanisme yang masuk akal → minat awal]
]

Solusi harus "menempel" pada masalah. Gunakan peta:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Unsur], [Pertanyaan],),
  table.hline(),
  [Masalah], [Keadaan apa yang telah diakui?],
  [Hambatan], [Mengapa keadaan itu terus terjadi?],
  [Mekanisme solusi], [Perubahan apa yang diusulkan?],
  [Manfaat awal], [Apa yang menjadi lebih mudah, cepat, aman, atau bermakna?],
  [Pemeriksaan], [Apakah kemungkinan ini relevan bagi pihak tersebut?],
)
Jika masalahnya ketidakpastian waktu tunggu, fitur "masuk dengan akun media sosial" tidak relevan. Jangan melekat pada solusi hanya karena kita telah menghabiskan waktu membuatnya.

=== Desire: Dari Fitur menuju Nilai
<desire-dari-fitur-menuju-nilai>
==== Fitur, Manfaat, dan Nilai
<fitur-manfaat-dan-nilai>
- #strong[Fitur:] apa yang dimiliki atau dilakukan solusi.
- #strong[Manfaat:] perubahan langsung yang dimungkinkan fitur.
- #strong[Nilai:] mengapa perubahan itu penting bagi pribadi tertentu.

Contoh:

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Fitur], [Manfaat], [Nilai bagi mahasiswa], [Nilai bagi pemilik],),
  table.hline(),
  [Estimasi waktu tunggu], [pengguna mengetahui kapan pesanan siap], [dapat kembali ke kelas tepat waktu], [kerumunan di kasir berkurang],
)
Nilai bersifat relasional. Fitur sama dapat memiliki nilai berbeda bagi peran berbeda.

==== Pitch Minat
<pitch-minat>
Gunakan lima langkah:

+ #strong[Hubungkan kembali dengan masalah.]
+ #strong[Perkenalkan kemungkinan solusi.]
+ #strong[Jelaskan mekanisme secara sederhana.]
+ #strong[Nyatakan manfaat yang mungkin, bukan janji berlebihan.]
+ #strong[Undang tanggapan.]

Contoh:

#quote(block: true)[
"Tadi Ibu menjelaskan bahwa kasir kewalahan mencatat pesanan sekaligus menjawab pertanyaan. Kita dapat mencoba papan antrean digital sederhana: pesanan diberi nomor dan statusnya diperbarui dari satu perangkat. Mahasiswa tidak perlu terus bertanya, sementara kasir dapat fokus mencatat. Apakah mekanisme ini layak kita lihat dalam contoh kecil?"
]

=== Repertoar untuk Menumbuhkan Minat
<repertoar-untuk-menumbuhkan-minat>
Dalam #emph[Daya Tarik], kisah, konsep, fakta, dan opini dipakai sebagai pesan yang membangkitkan ketertarikan @langi2025dayatarik. Pada tahap minat:

- #strong[kisah singkat] menunjukkan seseorang dalam masalah yang serupa;
- #strong[fakta tidak biasa] mengubah cara melihat masalah;
- #strong[konsep] memberi nama pada mekanisme;
- #strong[opini tentatif] mengundang pengujian;
- #strong[analogi] menghubungkan hal baru dengan pengalaman lama;
- #strong[prototipe] membuat kemungkinan dapat disentuh atau dicoba;
- #strong[pertanyaan] mengajak pihak lain melengkapi nilai dengan bahasanya sendiri.

Prototipe adalah komunikasi, bukan hanya artefak teknis. Ia membantu orang mengatakan, "Bagian ini berguna," atau "Ini tidak cocok dengan alur kerja kami."

=== Komunikasi Berlapis
<komunikasi-berlapis>
Berikan informasi sesuai kedalaman minat:

+ satu kalimat kemungkinan;
+ mekanisme ringkas;
+ contoh atau demonstrasi;
+ bukti dan rincian teknis bila diminta.

Lapisan mencegah penumpukan fitur. Mengatakan "Saya belum tahu; bagian itu perlu diuji" dapat memperkuat kredibilitas karena batas pengetahuan dinyatakan jujur.

=== Membaca Keadaan Minat
<membaca-keadaan-minat>
- #strong[Belum berminat:] kembali ke masalah, periksa relevansi, atau berhenti.
- #strong[Berminat:] jawab pertanyaan, berikan contoh, dan minta tanggapan.
- #strong[Sudah menginginkan hasil:] jangan terus menjejalkan fitur; bersiap membahas bukti, risiko, dan kelayakan.

Minat adalah hipotesis yang diuji melalui respons, bukan perasaan bangga komunikator.

=== Menyesuaikan Kedalaman, Bukan Memberi Label
<menyesuaikan-kedalaman-bukan-memberi-label>
Orang yang cenderung analitis mungkin meminta data dan asumsi. Orang yang praktis ingin melihat langkah kerja. Orang yang melihat gambaran besar mencari hubungan dengan tujuan. Orang yang berhati-hati bertanya tentang risiko. Kecenderungan ini adalah petunjuk sementara, bukan kotak permanen. Dengarkan pertanyaan aktual dan sesuaikan.

Peran juga mengubah bahasa. Insinyur menilai cara kerja, manajer menilai dampak dan sumber daya, pengguna menilai pengalaman, sedangkan keuangan menilai biaya dan risiko. Satu solusi memerlukan beberapa pintu masuk menuju makna.

=== Kegagalan Menumbuhkan Minat
<kegagalan-menumbuhkan-minat>
- #strong[Pembuangan fitur:] daftar kemampuan tanpa hubungan dengan masalah.
- #strong[Terlalu rinci:] jawaban tingkat empat diberikan untuk pertanyaan tingkat satu.
- #strong[Nilai generik:] "lebih efisien" tanpa menjelaskan bagi siapa dan pada ukuran apa.
- #strong[Kelekatan solusi:] komunikator membela produknya ketika data menunjukkan ketidakcocokan.
- #strong[Menutup terlalu cepat:] minat dianggap sebagai keputusan membeli atau menyetujui.

Ketika gagal, kembali ke kalimat pihak lain tentang masalah. Tanyakan, "Bagian mana yang belum terasa relevan?" Jawaban itu lebih berguna daripada mengulang pitch dengan energi lebih besar.

=== AI sebagai Peninjau Relevansi
<ai-sebagai-peninjau-relevansi>
AI dapat menandai jargon, mengubah fitur menjadi kemungkinan manfaat, atau mensimulasikan pertanyaan skeptis. Jangan meminta AI menciptakan manfaat yang tidak didukung. Setiap klaim tetap harus diperiksa.

=== Praktis: Detoks Fitur
<praktis-detoks-fitur>
Ambil deskripsi satu produk atau program. Tandai semua fitur. Untuk setiap fitur, tuliskan manfaat, nilai bagi satu peran, dan bukti yang masih diperlukan.

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([Fitur], [Manfaat mungkin], [Nilai bagi siapa?], [Bukti yang diperlukan],),
  table.hline(),
  [], [], [], [],
)
Hapus fitur yang tidak terhubung dengan masalah yang telah disepakati.

=== Perform: Pitch Masalah--Solusi
<perform-pitch-masalahsolusi>
Sampaikan pitch 60 detik, kemudian jawab pertanyaan selama dua menit. Mitra memainkan pelanggan yang memiliki satu informasi tersembunyi. Anda harus mendengarkan dan menyesuaikan, bukan mempertahankan naskah.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Kecocokan], [Solusi generik], [Solusi menempel pada masalah yang diakui],
  [Kejelasan mekanisme], [Fitur menumpuk], [Cara kerja ringkas dan dapat dibayangkan],
  [Nilai], [Sama bagi semua], [Relevan bagi pribadi/peran tertentu],
  [Dialog], [Monolog], [Respons dipakai untuk menguji dan menyesuaikan],
  [Kejujuran], [Janji berlebihan], [Batas dan kebutuhan bukti dinyatakan],
)
=== Refleksi
<refleksi-7>
+ Apakah saya menjelaskan solusi atau memamerkan teknologi?
+ Fitur mana yang tidak memberi nilai bagi pihak ini?
+ Pertanyaan apa yang menandakan minat?
+ Informasi apa yang belum saya ketahui?
+ Apakah relasi menjadi lebih terbuka untuk eksplorasi?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-8>
Minat tumbuh ketika kemungkinan solusi terhubung dengan masalah yang telah diakui. Komunikator menerjemahkan fitur menjadi manfaat dan nilai, menjelaskan mekanisme secara sederhana, menggunakan repertoar yang relevan, serta mengundang tanggapan. Minat bukan izin untuk langsung menutup kesepakatan; ia adalah undangan untuk menjelajahi lebih jauh.

#quote(block: true)[
#strong[Mulailah dari masalah mereka, bukan dari kecintaan Anda pada solusi.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-6>
Lihat #cite(<vargo2004evolving>, form: "prose"), #cite(<heath2007made>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== Laboratorium Kinerja I: Dari Sasaran menuju Minat
<laboratorium-kinerja-i-dari-sasaran-menuju-minat>
#block[
#callout(
body: 
[
#strong[Mengetahui TAIDA belum berarti mampu membuat komunikasi bergerak ketika kita berhadapan dengan pribadi yang nyata, respons yang tidak terduga, dan waktu yang terbatas.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-9>
Bab ini adalah laboratorium. Harta karunnya bukan konsep tambahan, melainkan bukti bahwa Anda mampu mengenali sasaran, memperoleh perhatian, mendengarkan respons, dan menumbuhkan minat tanpa mengorbankan relasi.

=== Tujuan Belajar
<tujuan-belajar-8>
Anda mampu menyiapkan peta komunikasi, melakukan percakapan Sasaran--Perhatian--Minat, menyesuaikan bahasa secara langsung, menggunakan umpan balik rekan, dan menyusun refleksi berbasis bukti.

=== Kata Kunci
<kata-kunci-8>
#strong[Laboratorium kinerja], #strong[keadaan TAIDA], #strong[simulasi], #strong[observasi], #strong[adaptasi], #strong[bukti performa], #strong[umpan balik], #strong[rekaman], dan #strong[refleksi perbaikan].

=== Persiapan: Dari Peta ke Medan
<persiapan-dari-peta-ke-medan>
Bawalah artefak Bab 5--7: pernyataan masalah, peta sasaran, pitch perhatian, dan pitch minat. Tandai asumsi yang belum dikonfirmasi. Laboratorium bukan tempat membuktikan bahwa naskah Anda benar; laboratorium adalah tempat menemukan apa yang perlu diperbaiki.

=== Attention: Ketika Rencana Bertemu Respons
<attention-ketika-rencana-bertemu-respons>
Dalam perjalanan studi saya, tidak ada naskah yang dapat menjamin hasil. Nilai bahasa Inggris yang membaik tidak otomatis menghasilkan penerimaan universitas. Surat penerimaan tidak otomatis menjamin keberangkatan. Setiap tahap membawa orang, kendala, dan keputusan baru.

Demikian pula komunikasi profesional. Peta memberi arah, tetapi respons menentukan langkah. Seseorang mungkin menyangkal masalah, meminta bukti, tertarik pada manfaat berbeda, atau menunjukkan bahwa kita berbicara kepada pihak yang salah.

=== Interest: Prinsip Laboratorium
<interest-prinsip-laboratorium>
+ #strong[Pribadi lebih penting daripada naskah.] Dengarkan meski respons mengubah rencana.
+ #strong[Keadaan lebih penting daripada jumlah kalimat.] Jangan bergerak ke minat sebelum perhatian terbentuk.
+ #strong[Bukti lebih penting daripada kesan diri.] Catat kata, pertanyaan, dan tindakan yang dapat diamati.
+ #strong[Perbaikan lebih penting daripada kesempurnaan pertama.] Setiap putaran harus menghasilkan revisi.
+ #strong[Relasi adalah ukuran keberhasilan.] Hasil yang dipaksakan bukan performa unggul.

=== Desire: Rangkaian Kinerja
<desire-rangkaian-kinerja>
==== Stasiun 1 --- Peta Pribadi dan Peran
<stasiun-1-peta-pribadi-dan-peran>
Susun satu halaman yang memuat sasaran, peran, konteks, riwayat relasi, masalah, bukti, wewenang, dan keadaan TAIDA awal.

==== Stasiun 2 --- Memperoleh Perhatian
<stasiun-2-memperoleh-perhatian>
Minta izin, sampaikan observasi--dampak--pemeriksaan, lalu diam dan dengarkan. Batas waktu pembuka 45 detik.

==== Stasiun 3 --- Menguji Masalah
<stasiun-3-menguji-masalah>
Ajukan sedikitnya dua pertanyaan. Parafrasakan masalah dan minta koreksi. Jika masalah tidak diakui, jangan memaksakan solusi.

==== Stasiun 4 --- Menumbuhkan Minat
<stasiun-4-menumbuhkan-minat>
Hubungkan masalah dengan kemungkinan solusi. Jelaskan mekanisme secara sederhana, nyatakan manfaat tentatif, dan undang tanggapan.

==== Stasiun 5 --- Membaca Keadaan
<stasiun-5-membaca-keadaan>
Pilih satu kesimpulan dengan bukti:

- belum memperoleh perhatian;
- perhatian terbentuk tetapi belum berminat;
- minat awal terbentuk;
- pihak lain telah meminta pembahasan lebih lanjut; atau
- percakapan berhenti secara sehat.

=== Praktis: Skenario Utama
<praktis-skenario-utama>
#quote(block: true)[
Sebuah program ingin mengurangi makanan terbuang di kantin kampus. Mahasiswa menginginkan pilihan yang tersedia sampai sore. Pemilik kantin khawatir kerugian. Petugas membutuhkan proses sederhana. Tim mahasiswa mempunyai gagasan pencatatan permintaan, tetapi belum mengetahui akar pemborosan.
]

Peran dimainkan oleh komunikator, pihak sasaran, dan pengamat. Pihak sasaran menerima kartu informasi tersembunyi, misalnya: data pemborosan tidak konsisten; pernah ada program serupa yang menambah pekerjaan; atau masalah terbesar justru prakiraan acara kampus.

==== Lembar Keadaan Sebelum Percakapan
<lembar-keadaan-sebelum-percakapan>
Sebelum simulasi, masing-masing pelaku menulis tanpa saling melihat:

- apa yang ia ketahui dan belum ketahui;
- apa yang ia inginkan;
- apa yang ia khawatirkan;
- apa yang dapat ia putuskan; dan
- bukti apa yang akan membuatnya bergerak ke keadaan berikutnya.

Perbandingan lembar setelah simulasi memperlihatkan betapa mudahnya komunikator mengira telah memahami orang lain.

=== Umpan Balik Berbasis Bukti
<umpan-balik-berbasis-bukti>
Pengamat tidak berkata, "Bagus" atau "Kurang meyakinkan" saja. Gunakan format:

#quote(block: true)[
#strong[Ketika Anda …, saya mengamati respons …. Hal itu menunjukkan keadaan mungkin …. Saya menyarankan ….]
]

Contoh:

#quote(block: true)[
"Ketika Anda menyebut fitur aplikasi sebelum mengonfirmasi penyebab pemborosan, pihak sasaran berhenti bertanya dan menyilangkan tangan. Itu menunjukkan minat belum terbentuk. Saya menyarankan kembali ke pertanyaan tentang alur pencatatan."
]

Isyarat nonverbal tidak boleh diperlakukan sebagai kepastian; pengamat perlu menghubungkannya dengan respons verbal.

=== AI sebagai Mitra Latihan
<ai-sebagai-mitra-latihan>
AI dapat memainkan peran skeptis dengan informasi dan kendala yang ditentukan, tetapi simulasi AI tidak menggantikan manusia. Gunakan untuk menghasilkan variasi respons, bukan menilai kepribadian atau memberi nilai akhir.

=== Perform: Tiga Putaran
<perform-tiga-putaran>
==== Putaran 1 --- Diagnosis
<putaran-1-diagnosis>
Lakukan percakapan tiga menit tanpa interupsi pengamat. Catat keadaan awal dan akhir.

==== Putaran 2 --- Umpan Balik dan Revisi
<putaran-2-umpan-balik-dan-revisi>
Pengamat memberikan dua bukti kekuatan dan satu prioritas perbaikan. Komunikator merevisi peta atau pitch selama lima menit.

==== Putaran 3 --- Uji Ulang
<putaran-3-uji-ulang>
Ulangi dengan respons pihak sasaran yang berbeda. Nilai kemampuan beradaptasi, bukan hafalan.

==== Debrief --- Memisahkan Niat dan Dampak
<debrief-memisahkan-niat-dan-dampak>
Komunikator menjelaskan niatnya setelah pihak sasaran terlebih dahulu menceritakan dampak yang dialami. Perbedaan keduanya menjadi bahan belajar. Kalimat "Saya bermaksud membantu" tidak membatalkan pengalaman pihak lain; pengalaman pihak lain juga tidak otomatis membuktikan niat buruk.

Tutup dengan satu keputusan: pertahankan, hentikan, atau ubah perilaku komunikasi tertentu pada putaran berikutnya.

=== Bukti Performa
<bukti-performa>
Portofolio memuat:

+ peta pribadi dan peran;
+ pernyataan masalah;
+ naskah awal dan revisi;
+ rekaman 3--5 menit atau lembar observasi;
+ dua umpan balik rekan;
+ bukti keadaan TAIDA sebelum dan sesudah; serta
+ refleksi 300--500 kata.

=== Rubrik Laboratorium
<rubrik-laboratorium>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Kriteria], [Dasar], [Cakap], [Unggul],),
  table.hline(),
  [Pemetaan sasaran], [Kategori umum], [Peran, konteks, dan wewenang jelas], [Asumsi dan riwayat relasi juga diperiksa],
  [Perhatian], [Pembuka generik], [Relevan, berbukti, dan ringkas], [Disesuaikan secara halus terhadap respons],
  [Mendengarkan], [Menunggu giliran], [Mengajukan dan memparafrasakan], [Mengubah rumusan berdasarkan informasi baru],
  [Minat], [Menumpuk fitur], [Masalah--mekanisme--manfaat terhubung], [Pihak lain ikut merumuskan nilai],
  [Refleksi], [Berisi kesan], [Menggunakan bukti], [Menunjukkan revisi dan transfer pembelajaran],
  [Relasi], [Tekanan terasa], [Kebebasan dan hormat terjaga], [Kepercayaan bertambah meski belum sepakat],
)
=== Refleksi
<refleksi-8>
+ Di titik mana saya kehilangan kontak dengan respons?
+ Asumsi apa yang dibatalkan oleh percakapan?
+ Kalimat atau pertanyaan mana yang mengubah keadaan?
+ Apakah penghentian percakapan justru menjadi hasil yang sehat?
+ Satu kebiasaan apa yang akan saya bawa ke tahap keinginan?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-9>
Kompetensi terlihat ketika konsep dapat digunakan di tengah ketidakpastian. Dari sasaran menuju minat, komunikator memetakan pribadi, memperoleh perhatian secara relevan, menguji masalah, menawarkan kemungkinan, membaca respons, dan menyesuaikan langkah. Laboratorium mengubah kesalahan menjadi data perbaikan.

#quote(block: true)[
#strong[Jangan pertahankan naskah ketika manusia di hadapan Anda memberi informasi yang lebih baik.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-7>
Praktik umpan balik dan keamanan belajar dapat diperdalam melalui #cite(<edmondson1999psychological>, form: "prose") dan #cite(<schein2013humble>, form: "prose").

== TAIDA III: Dari Minat menuju Keinginan
<taida-iii-dari-minat-menuju-keinginan>
#block[
#callout(
body: 
[
#strong[Minat berkata, "Ini menarik." Keinginan berkata, "Hasil itu penting bagi saya dan layak diperjuangkan."]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-10>
Harta karun bab ini adalah kemampuan membantu orang membayangkan keadaan lebih baik, memahami cara kerja solusi, menilai bukti serta risiko, dan membentuk keinginan tanpa manipulasi.

=== Tujuan Belajar
<tujuan-belajar-9>
Anda mampu membedakan minat dan keinginan, menerjemahkan fitur menjadi hasil, menggunakan demonstrasi, analogi, data, dan cerita, menyatakan risiko serta ketidakpastian, menjawab keberatan, dan membuat #emph[Demonstrasi Pembangun Keinginan].

=== Kata Kunci
<kata-kunci-9>
#strong[Keinginan], #strong[keadaan sekarang], #strong[keadaan masa depan], #strong[fitur], #strong[manfaat], #strong[nilai], #strong[hasil], #strong[bukti], #strong[kredibilitas], #strong[risiko], #strong[keberatan], dan #strong[kebebasan memilih].

=== Persiapan: Apa yang Membuat Anda Bersedia Berjuang?
<persiapan-apa-yang-membuat-anda-bersedia-berjuang>
Pikirkan satu kesempatan yang semula hanya menarik, kemudian menjadi sungguh Anda inginkan. Bukti, pengalaman, dukungan, atau gambaran masa depan apa yang mengubah keadaan itu?

=== Attention: Satu Surat Penerimaan
<attention-satu-surat-penerimaan>
Setelah tujuh surat penolakan, datang satu surat penerimaan dari University of Manitoba. Surat itu lebih dari informasi administratif. Ia merupakan bukti kredibel bahwa jalan studi lanjut benar-benar terbuka. Dukungan WUSC, kesediaan Professor Witold Kinsner menerima saya, dan reputasi baik rekan yang lebih dahulu belajar di sana membuat kemungkinan abstrak menjadi masa depan yang dapat diperjuangkan.

#block[
#callout(
body: 
[
Impian telah lama ada, tetapi keinginan yang siap ditindaklanjuti memerlukan jembatan: kemungkinan yang jelas, dukungan yang dapat dipercaya, serta bukti bahwa langkah berikutnya masuk akal.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Dari Kemungkinan menuju Masa Depan yang Bernilai
<interest-dari-kemungkinan-menuju-masa-depan-yang-bernilai>
Minat berfokus pada solusi: "Bagaimana ini bekerja?" Keinginan berfokus pada hasil: "Apakah keadaan masa depan itu penting, dapat dipercaya, dan sesuai bagi saya?"

Gunakan rangkaian:

#quote(block: true)[
#strong[Fitur → Manfaat → Nilai → Hasil yang Diinginkan]
]

Contoh:

- fitur: estimasi waktu tunggu;
- manfaat: pengguna dapat memilih waktu pengambilan;
- nilai: kendali dan kepastian;
- hasil: mahasiswa makan tanpa terlambat kuliah, sementara kantin mengelola kerumunan.

Keinginan tidak diciptakan dari nol. Ia tumbuh dari kebutuhan, aspirasi, identitas, dan nilai yang telah dimiliki pribadi.

=== Desire: Menjembatani Keadaan Sekarang dan Masa Depan
<desire-menjembatani-keadaan-sekarang-dan-masa-depan>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Unsur], [Pertanyaan],),
  table.hline(),
  [Keadaan sekarang], [Beban, kerugian, atau peluang apa yang dialami?],
  [Keadaan masa depan], [Apa yang menjadi lebih baik secara konkret?],
  [Mekanisme], [Bagaimana solusi menghasilkan perubahan?],
  [Bukti], [Mengapa klaim layak dipercaya?],
  [Pengorbanan], [Biaya, waktu, usaha, dan perubahan apa yang diperlukan?],
  [Risiko], [Apa yang dapat gagal dan bagaimana menguranginya?],
)
==== Demonstrasi
<demonstrasi>
Tunjukkan alur utama, bukan semua fitur. Biarkan orang mencoba dan mengajukan pertanyaan. Demonstrasi yang baik mengubah klaim menjadi pengalaman.

==== Analogi
<analogi>
Analogi membuat mekanisme dapat dibayangkan. Jelaskan juga batasnya agar tidak menyesatkan.

==== Data dan Bukti
<data-dan-bukti>
Gunakan data yang relevan, sumber yang jelas, ukuran pembanding, dan keterbatasan. Bedakan hasil uji kecil dari kepastian skala besar.

==== Cerita Pengguna
<cerita-pengguna>
Cerita menghadirkan manusia, tantangan, pilihan, dan hasil. #emph[Daya Tarik] menempatkan kisah sebagai pesan yang membuat pendengar menghubungkan pengalaman orang lain dengan hidupnya @langi2025dayatarik. Lindungi privasi dan jangan menggunakan kisah tunggal sebagai bukti universal.

==== Konsep
<konsep>
Konsep menjelaskan "mesin abstrak" di balik solusi: sumber daya apa yang diarahkan untuk mengatasi beban apa. Misalnya, konsep "pemesanan awal" mengalihkan sebagian keputusan dari jam sibuk ke waktu sebelum kedatangan.

=== Kredibilitas Komunikator
<kredibilitas-komunikator>
Kredibilitas bukan hanya percaya diri. Ia dibangun melalui kompetensi, bukti, konsistensi, kepentingan yang dinyatakan, dan keberanian mengakui batas. Kalimat "Dalam uji 20 pengguna, waktu tunggu turun; kami belum mengetahui hasil pada 500 pengguna" lebih kuat daripada "Sistem ini pasti menyelesaikan antrean."

=== Keberatan adalah Informasi
<keberatan-adalah-informasi>
Kelompokkan keberatan:

- #strong[nilai:] hasil tidak cukup penting;
- #strong[kepercayaan:] bukti atau pihak pembawa belum meyakinkan;
- #strong[biaya:] pengorbanan terlalu besar;
- #strong[usaha:] perubahan perilaku terlalu berat;
- #strong[risiko:] kemungkinan dampak buruk belum dapat diterima.

Jangan melawan keberatan. Dengarkan, parafrasa, periksa, lalu jawab dengan bukti atau revisi. Kadang keberatan menunjukkan solusi memang tidak cocok.

=== Tangga Bukti
<tangga-bukti>
Tidak semua bukti memiliki kekuatan yang sama. Susun secara bertahap:

+ klaim dan penjelasan mekanisme;
+ contoh atau prototipe;
+ pengalaman pengguna;
+ data uji dengan konteks;
+ perbandingan dengan alternatif;
+ hasil penerapan yang dapat direplikasi.

Bukti yang dibutuhkan bergantung pada besarnya keputusan dan risiko. Uji coba kegiatan mahasiswa tidak memerlukan standar yang sama dengan alat medis, tetapi keduanya tetap membutuhkan kejujuran tentang apa yang diketahui.

=== Satu Solusi, Beberapa Sumber Keinginan
<satu-solusi-beberapa-sumber-keinginan>
Anggota tim mungkin menginginkan berkurangnya pekerjaan berulang. Manajer menginginkan kepastian jadwal. Pengguna menginginkan kemudahan. Petugas kepatuhan menginginkan jejak audit dan perlindungan data. Jangan mengganti fakta, tetapi pilih hasil, bukti, dan risiko yang relevan bagi tanggung jawab masing-masing.

Hindari stereotip kepribadian. Orang yang analitis tetap memiliki emosi; orang yang antusias tetap membutuhkan bukti. Ajukan pertanyaan, "Apa yang paling perlu Anda yakini sebelum mempertimbangkan langkah berikutnya?"

=== Etika Keinginan
<etika-keinginan>
Komunikasi etis:

- tidak menciptakan kelangkaan atau urgensi palsu;
- tidak menyembunyikan biaya dan risiko material;
- tidak mengeksploitasi ketakutan, kesepian, atau kerentanan;
- memberi waktu dan pilihan untuk menolak;
- membedakan harapan dari jaminan.

Kemasan nonverbal dapat menguatkan kejelasan, tetapi tidak boleh menutupi isi yang lemah @langi2025dayatarik.

=== AI sebagai Pengkritik Bukti
<ai-sebagai-pengkritik-bukti>
AI dapat menghasilkan kemungkinan keberatan, membandingkan versi penjelasan, atau menandai klaim tanpa bukti. Mintalah AI mencari kelemahan, bukan hanya membuat bahasa lebih persuasif. Keputusan tentang nilai dan risiko tetap milik manusia.

=== Praktis: Empat Cara Menjelaskan Satu Solusi
<praktis-empat-cara-menjelaskan-satu-solusi>
Pilih satu solusi dan buat:

+ penjelasan teknis 100 kata;
+ analogi beserta batasnya;
+ demonstrasi tiga langkah;
+ cerita pengguna 150 kata; dan
+ tabel bukti, risiko, serta hal yang belum diketahui.

Uji kepada dua peran berbeda. Catat format mana yang membantu masing-masing melihat hasil masa depan.

=== Perform: Demonstrasi Pembangun Keinginan
<perform-demonstrasi-pembangun-keinginan>
Lakukan presentasi 4--5 menit:

- nyatakan keadaan sekarang dan hasil yang diinginkan;
- tunjukkan mekanisme;
- gunakan sedikitnya dua bentuk bukti;
- akui satu risiko atau batas;
- tanggapi satu keberatan; dan
- periksa keadaan pihak lain tanpa memaksa tindakan.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Hasil yang diinginkan], [Generik], [Spesifik dan relevan bagi peran],
  [Mekanisme], [Klaim tanpa cara kerja], [Hubungan sebab-akibat dapat dipahami],
  [Bukti], [Hiasan atau testimoni tunggal], [Proporsional dan berketerbatasan jelas],
  [Risiko], [Disembunyikan], [Diakui dan dimitigasi secara realistis],
  [Etika], [Menekan keputusan], [Kebebasan memilih dan relasi terjaga],
)
=== Refleksi
<refleksi-9>
+ Hasil apa yang sebenarnya diinginkan pihak lain?
+ Bukti mana yang paling relevan, bukan paling mengesankan?
+ Apa yang dapat gagal?
+ Keberatan apa yang mengubah desain solusi?
+ Apakah keinginan tumbuh dari nilai pihak lain atau tekanan saya?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-10>
Keinginan tumbuh ketika orang dapat melihat masa depan yang bernilai, memahami mekanisme, mempercayai bukti, dan menerima risiko secara sadar. Komunikator menghubungkan fitur dengan manfaat, nilai, dan hasil; menggunakan demonstrasi, analogi, data, konsep, serta cerita; dan tetap membuka kebebasan untuk menolak.

#quote(block: true)[
#strong[Jangan membuat orang sekadar terpesona. Bantulah mereka menilai apakah masa depan yang ditawarkan benar-benar bernilai dan layak dipercaya.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-8>
Lihat #cite(<heath2007made>, form: "prose"), #cite(<vargo2004evolving>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== TAIDA IV: Kesepakatan dan Tindakan
<taida-iv-kesepakatan-dan-tindakan>
#block[
#callout(
body: 
[
#strong[Banyak percakapan berakhir dengan "nanti kita bicarakan lagi" karena keinginan belum diterjemahkan menjadi siapa melakukan apa, kapan, dengan sumber daya apa, dan bagaimana keberhasilannya diperiksa.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-11>
Harta karun bab ini adalah kemampuan mengubah keinginan menjadi kesepakatan yang layak, spesifik, dan dapat dilaksanakan sambil menghormati pilihan setiap pihak. Hasil yang sehat dapat berupa kesepakatan penuh, sebagian, penundaan dengan syarat jelas, atau "tidak" yang bertanggung jawab.

=== Tujuan Belajar
<tujuan-belajar-10>
Anda mampu membedakan keinginan, niat, komitmen, kesepakatan, dan tindakan; menemukan penghalang kelayakan; memeriksa wewenang; menyusun dokumen kesepakatan; menentukan bukti selesai; serta menjaga relasi sesudah keputusan.

=== Kata Kunci
<kata-kunci-10>
#strong[Tindakan], #strong[kelayakan], #strong[komitmen], #strong[kesepakatan], #strong[wewenang], #strong[keterjangkauan], #strong[langkah berikutnya], #strong[definisi selesai], #strong[akuntabilitas], dan #strong[relasi pascakeputusan].

=== Persiapan: Kesepakatan yang Kabur
<persiapan-kesepakatan-yang-kabur>
Tuliskan satu "kesepakatan" kelompok yang tidak terlaksana. Apakah pelakunya jelas? Tenggatnya ada? Sumber daya tersedia? Ukuran selesai disepakati? Sering kali masalah bukan kemauan, melainkan ketidakjelasan.

=== Attention: Sehari sebelum Keberangkatan
<attention-sehari-sebelum-keberangkatan>
Pada Desember 1989, saya bergabung dengan rombongan yang bersiap berangkat. Sehari sebelum penerbangan, muncul kabar bahwa proyek yang membiayai saya hendak menunda keberangkatan saya dan tiga rekan. Tiket, rencana, dan keinginan belum cukup; ada wewenang serta koordinasi yang harus dipastikan.

Kami mendatangi kantor proyek dan memohon agar dapat berangkat. Menjelang malam, izin diberikan. Keesokan hari, tindakan nyata baru mungkin terjadi: saya menuju bandara dan menaiki pesawat.

#block[
#callout(
body: 
[
Keinginan dapat sangat kuat, tetapi tindakan selalu hidup di dalam kenyataan: jadwal, otoritas, biaya, dokumen, risiko, dan komitmen banyak orang. Komunikasi membantu semua unsur itu bertemu.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Keinginan Tidak Otomatis Menjadi Tindakan
<interest-keinginan-tidak-otomatis-menjadi-tindakan>
Ada tangga keadaan:

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Keadaan], [Contoh],),
  table.hline(),
  [Keinginan], ["Saya ingin program ini berjalan."],
  [Niat], ["Saya berencana ikut."],
  [Komitmen], ["Saya bersedia mengambil tanggung jawab."],
  [Kesepakatan], ["Kita menerima pembagian dan syarat ini."],
  [Tindakan], [Pekerjaan dimulai dan bukti dihasilkan.],
)
Jangan memperlakukan antusiasme sebagai janji. Komitmen memerlukan kemampuan, wewenang, dan kesediaan menanggung konsekuensi.

=== Desire: Menemukan Penghalang Kelayakan
<desire-menemukan-penghalang-kelayakan>
Keterjangkauan lebih luas daripada harga:

- #strong[uang:] apakah anggaran tersedia?
- #strong[waktu:] kapan pekerjaan dapat dilakukan?
- #strong[kemampuan:] apakah pengetahuan dan alat cukup?
- #strong[usaha:] perubahan perilaku apa yang diperlukan?
- #strong[wewenang:] siapa yang boleh memutuskan?
- #strong[risiko:] kerugian apa yang mungkin terjadi?
- #strong[perubahan:] proses atau identitas apa yang harus ditinggalkan?

Tanyakan, "Apa yang menghalangi kita bergerak?" bukan "Mengapa Anda belum setuju?" Pertanyaan pertama membuka pemecahan masalah; pertanyaan kedua mudah terdengar sebagai tuduhan.

=== Formula Kesepakatan
<formula-kesepakatan>
Kesepakatan yang dapat dilaksanakan menjawab:

#quote(block: true)[
#strong[Siapa → melakukan apa → kapan → dengan sumber daya/syarat apa → apa yang dianggap selesai → bagaimana tindak lanjutnya.]
]

- Kabur: "Tim desain segera memperbaiki tampilan."
- Spesifik: "Rani mengirim prototipe tiga layar utama pada Jumat pukul 16.00 melalui repositori proyek. Dimas meninjau aksesibilitas sebelum Senin pukul 10.00. Selesai berarti semua kriteria pada daftar uji telah diberi status."

Tujuan spesifik dan menantang, bila diterima dan disertai umpan balik, membantu kinerja @locke2002building. Namun, kejelasan tidak boleh berubah menjadi beban yang mustahil.

=== Kesepakatan Bukan Keseragaman Pikiran
<kesepakatan-bukan-keseragaman-pikiran>
Orang dapat berbeda pendapat tetapi menyetujui tindakan terkoordinasi. Kesepakatan juga tidak selalu berarti "ya" terhadap seluruh usulan. Hasil dapat berupa:

- uji coba kecil;
- kesepakatan sebagian;
- keputusan menunggu data;
- pembagian risiko;
- atau tidak ada kesepakatan.

"Tidak" yang jelas lebih berguna daripada "ya" yang tidak akan dilaksanakan. Hormati penolakan, tanyakan apakah ada syarat atau alternatif, dan jangan menghukum orang karena menyatakan batas.

=== Posisi dan Kepentingan dalam Menutup Kesepakatan
<posisi-dan-kepentingan-dalam-menutup-kesepakatan>
Ketika satu pihak berkata, "Harus selesai Jumat," Jumat adalah posisi. Kepentingannya mungkin presentasi Senin, kewajiban pelaporan, atau kebutuhan waktu untuk menguji. Jika Jumat mustahil, memahami kepentingan membuka alternatif: menyelesaikan bagian kritis, mengurangi ruang lingkup, atau menyediakan bukti sementara.

Negosiasi bukan upaya membuat pihak lain menyerah. Ia mencari susunan yang layak di antara kepentingan, kendala, serta alternatif @fisher2011getting. Jika tidak ada irisan yang dapat diterima, nyatakan tanpa membuat komitmen palsu.

=== Pemeriksaan Kesepakatan
<pemeriksaan-kesepakatan>
Sebelum menutup percakapan, periksa:

+ Apakah pihak yang berjanji memiliki wewenang?
+ Apakah semua orang memahami istilah dengan cara yang sama?
+ Apakah sumber daya dan ketergantungan tersedia?
+ Apakah risiko serta syarat dinyatakan?
+ Apakah ukuran selesai dapat diamati?
+ Apakah langkah pertama dan waktu pemeriksaan jelas?

Kirim konfirmasi tertulis singkat. Tulisan menjadi memori bersama, bukan senjata untuk saling menyalahkan.

=== Lingkar Komitmen
<lingkar-komitmen>
Tindakan perlu dipantau melalui lingkar:

#quote(block: true)[
#strong[Janji → pelaksanaan → bukti → pemeriksaan → penerimaan atau perbaikan]
]

Penerima tidak menunggu sampai tenggat untuk menemukan kegagalan besar. Penanggung jawab juga tidak menunggu ditanya untuk melaporkan hambatan. Titik pemeriksaan yang proporsional membuat masalah terlihat ketika masih dapat diperbaiki.

Setelah pekerjaan diterima, catat pelajaran dan tutup komitmen secara eksplisit. Tugas yang menggantung dalam ingatan bersama menguras kepercayaan.

=== Tindakan dan Relasi
<tindakan-dan-relasi>
Nilai dua hasil:

- #strong[hasil tugas:] apakah tindakan dilakukan dan tujuan tercapai?
- #strong[hasil relasi:] apakah kepercayaan, rasa hormat, dan kemungkinan bekerja kembali tetap sehat?

Komitmen yang dipenuhi memperkuat relasi. Jika keadaan berubah, beri kabar sebelum tenggat, jelaskan dampak, dan negosiasikan ulang.

=== AI sebagai Peninjau Kesepakatan
<ai-sebagai-peninjau-kesepakatan>
AI dapat menandai pelaku, tenggat, syarat, ketergantungan, dan istilah kabur; atau merangkum rapat untuk dikonfirmasi. AI tidak otomatis memiliki wewenang untuk membuat janji. Manusia harus menyetujui catatan akhir dan bertanggung jawab atas komitmen.

=== Praktis: Dari Kabur Menjadi Terlaksana
<praktis-dari-kabur-menjadi-terlaksana>
Perbaiki kalimat berikut:

- "Nanti kita perbaiki datanya."
- "Bagian promosi akan segera menghubungi peserta."
- "Kita coba aplikasinya secepat mungkin."

Untuk masing-masing, tambahkan siapa, apa, kapan, syarat, definisi selesai, dan pemeriksaan.

=== Perform: Dokumen Kesepakatan
<perform-dokumen-kesepakatan>
Lakukan simulasi lima menit dari keadaan keinginan menuju tindakan. Satu pihak menginginkan solusi; pihak lain memegang kendala tersembunyi. Hasilkan dokumen satu halaman:

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Unsur], [Isi kesepakatan],),
  table.hline(),
  [Tujuan bersama], [],
  [Pihak dan wewenang], [],
  [Tindakan dan penanggung jawab], [],
  [Tenggat], [],
  [Sumber daya/syarat], [],
  [Risiko dan mitigasi], [],
  [Definisi selesai], [],
  [Langkah pertama], [],
  [Waktu tinjauan], [],
  [Status], [penuh / sebagian / belum sepakat],
)
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Kelayakan], [Hambatan diabaikan], [Uang, waktu, kemampuan, wewenang, dan risiko diperiksa],
  [Kejelasan], [Banyak kata kabur], [Pelaku, tindakan, tenggat, dan bukti jelas],
  [Komitmen], [Diasumsikan], [Dikonfirmasi oleh pihak berwenang],
  [Etika], [Tekanan untuk "ya"], [Penolakan dan alternatif dihormati],
  [Relasi], [Berakhir transaksional], [Tindak lanjut dan kepercayaan dijaga],
)
=== Refleksi
<refleksi-10>
+ Apakah saya menganggap keinginan sebagai komitmen?
+ Penghalang apa yang baru terlihat setelah bertanya?
+ Siapa sebenarnya memiliki wewenang?
+ Apakah definisi selesai dipahami sama?
+ Bagaimana kita akan berkomunikasi jika keadaan berubah?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-11>
Perjalanan dari keinginan menuju tindakan membutuhkan pemeriksaan kelayakan, wewenang, sumber daya, risiko, dan komitmen. Kesepakatan yang baik menyatakan siapa melakukan apa, kapan, dengan syarat apa, apa yang dianggap selesai, dan bagaimana tindak lanjut dilakukan. Tidak ada kesepakatan dapat menjadi hasil sehat apabila dinyatakan jujur.

#quote(block: true)[
#strong[Kesepakatan adalah jembatan dari bahasa menuju kenyataan; tindakan yang dapat dipercaya adalah jembatan menuju relasi berikutnya.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-9>
Lihat #cite(<locke2002building>, form: "prose"), #cite(<fisher2011getting>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== Negosiasi Banyak Pihak: Mencari Kesepakatan yang Dapat Diterima
<negosiasi-banyak-pihak-mencari-kesepakatan-yang-dapat-diterima>
#block[
#callout(
body: 
[
#strong[Perbedaan tujuan tidak selalu menandakan permusuhan. Sering kali setiap pihak melihat bagian masalah yang berbeda, menanggung kendala berbeda, dan memiliki wewenang yang berbeda.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-12>
Harta karun bab ini adalah kemampuan memetakan pihak, membedakan posisi dan kepentingan, mengembangkan pilihan, merundingkan pertukaran, serta menghasilkan kesepakatan yang dapat diterima tanpa membungkam pihak yang lebih lemah.

=== Tujuan Belajar
<tujuan-belajar-11>
Anda mampu menyusun peta pemangku kepentingan, membedakan posisi--kepentingan--kendala--nilai, menemukan wilayah kesepakatan, mengelola perbedaan bahasa dan kuasa, memfasilitasi simulasi banyak pihak, serta menghasilkan #emph[Kesepakatan Negosiasi dan Refleksi].

=== Kata Kunci
<kata-kunci-11>
#strong[Negosiasi], #strong[pemangku kepentingan], #strong[posisi], #strong[kepentingan], #strong[kendala], #strong[alternatif], #strong[pertukaran], #strong[wilayah kesepakatan], #strong[kuasa], #strong[fasilitator], #strong[perbedaan pendapat], dan #strong[kesepakatan yang dapat diterima].

=== Persiapan: Satu Masalah, Banyak Kenyataan
<persiapan-satu-masalah-banyak-kenyataan>
Untuk rencana pemesanan digital di kantin, tuliskan apa yang mungkin diinginkan mahasiswa, pemilik, kasir, tim teknis, bagian keuangan, dan pihak yang tidak memakai telepon pintar. Adakah keinginan yang tampak bertentangan?

=== Attention: Tidak Ada Perjalanan yang Berdiri Sendiri
<attention-tidak-ada-perjalanan-yang-berdiri-sendiri>
Keberangkatan studi saya pada 1989 tampak seperti pencapaian seorang individu. Jika dilihat lebih dekat, ada banyak pihak: keluarga, ITB, PAU Mikroelektronika, program World Bank, WUSC, instruktur bahasa, universitas, profesor penerima, dan rekan yang lebih dahulu membangun reputasi. Masing-masing membawa tujuan, aturan, jadwal, serta kewenangan.

Ketika keberangkatan hampir ditunda, masalahnya bukan sekadar "saya ingin berangkat". Ada keputusan antarpihak yang perlu diselaraskan. Pengalaman itu mengingatkan bahwa tindakan profesional sering merupakan hasil jaringan relasi dan kesepakatan.

=== Interest: Pemangku Kepentingan adalah Pribadi
<interest-pemangku-kepentingan-adalah-pribadi>
Peta pemangku kepentingan membantu melihat sistem, tetapi kotak pada diagram bukan manusia. Pendekatan pemangku kepentingan menuntut organisasi memperhitungkan pihak yang dapat memengaruhi atau dipengaruhi oleh tujuan bersama @freeman1984strategic. Untuk setiap pihak, petakan:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Unsur], [Pertanyaan],),
  table.hline(),
  [Pribadi/peran], [Siapa hadir sebagai siapa?],
  [Tujuan], [Hasil apa yang dikejar?],
  [Posisi], [Usulan atau tuntutan apa yang dinyatakan?],
  [Kepentingan], [Mengapa posisi itu penting?],
  [Kendala], [Apa yang membatasi pilihan?],
  [Wewenang], [Apa yang dapat diputuskan atau dijanjikan?],
  [Batas penerimaan], [Apa yang wajib, diinginkan, dan tidak dapat diterima?],
  [Keadaan TAIDA], [Sejauh mana ia memahami dan menginginkan pilihan?],
)
Pihak yang diam belum tentu setuju. Pihak berkuasa belum tentu paling terdampak. Negosiasi yang bertanggung jawab memberi cara aman bagi informasi dari pihak berdaya rendah untuk masuk.

=== Desire: Posisi dan Kepentingan
<desire-posisi-dan-kepentingan>
Pendekatan negosiasi berbasis kepentingan memisahkan tuntutan yang dinyatakan dari kebutuhan di baliknya @fisher2011getting.

- Posisi mahasiswa: "Semua transaksi harus digital."
- Kepentingan: kecepatan dan kepastian.
- Posisi kasir: "Jangan gunakan sistem baru."
- Kepentingan: beban kerja yang dapat dikelola dan rasa aman terhadap pekerjaan.

Jika hanya posisi diperdebatkan, pilihannya menang atau kalah. Ketika kepentingan terlihat, pilihan baru muncul: sistem hibrida, uji coba terbatas, pelatihan, pembagian tugas, atau antrean digital tanpa pembayaran digital.

==== Preferensi, Kendala, dan Nilai
<preferensi-kendala-dan-nilai>
- #strong[Preferensi:] pilihan yang disukai dan relatif mudah dinegosiasikan.
- #strong[Kendala:] batas nyata seperti hukum, anggaran, waktu, atau kapasitas.
- #strong[Nilai:] prinsip yang dianggap penting, seperti keselamatan, keadilan, atau privasi.

Jangan menyebut preferensi sebagai kendala untuk menghindari dialog. Jangan pula menawar nilai keselamatan seolah hanya selera.

=== Menciptakan Pilihan sebelum Menilai
<menciptakan-pilihan-sebelum-menilai>
Pisahkan dua kegiatan:

+ #strong[Menghasilkan:] buat sebanyak mungkin pilihan tanpa keputusan dini.
+ #strong[Menilai:] bandingkan manfaat, biaya, risiko, penerimaan, dan dampak.

#table(
  columns: (14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%),
  align: (auto,auto,auto,auto,auto,auto,auto,),
  table.header([Pilihan], [Mahasiswa], [Pemilik], [Kasir], [Teknis], [Keuangan], [Pihak terdampak],),
  table.hline(),
  [A], [], [], [], [], [], [],
  [B], [], [], [], [], [], [],
)
Kompromi membagi perbedaan; penciptaan nilai mencari susunan yang memanfaatkan perbedaan. Pihak yang menghargai waktu dan pihak yang menghargai biaya dapat bertukar jadwal, ruang lingkup, atau sumber daya.

=== Kesepakatan yang Dapat Diterima
<kesepakatan-yang-dapat-diterima>
Kesepakatan tidak mengharuskan semua pihak berpikir sama atau sangat senang. Ia perlu:

- memenuhi syarat minimum setiap pihak yang sah;
- tidak melanggar batas etik atau hukum;
- lebih baik daripada alternatif terbaik tanpa kesepakatan;
- menjelaskan pembagian manfaat, beban, dan risiko;
- dapat dilaksanakan oleh pihak berwenang; dan
- menyediakan cara meninjau serta memperbaiki.

Jika wilayah penerimaan tidak bertemu, "tidak ada kesepakatan" dapat menjadi hasil yang benar. Jangan membuat janji atas nama pihak yang tidak memberi wewenang.

=== Pertukaran dan Dampak Distribusi
<pertukaran-dan-dampak-distribusi>
Pilihan "terbaik" secara total dapat membebani satu kelompok secara tidak adil. Karena itu, evaluasi bukan hanya jumlah manfaat, tetapi distribusinya:

- siapa memperoleh manfaat dan kapan;
- siapa membayar biaya;
- siapa menanggung risiko jika gagal;
- siapa dapat keluar dari keputusan;
- siapa tidak hadir tetapi terdampak.

Pertukaran perlu dinyatakan terbuka. Peluncuran lebih cepat mungkin mengurangi pengujian; biaya lebih rendah mungkin menambah pekerjaan manual; keamanan lebih tinggi mungkin mengurangi kemudahan. Menyembunyikan pertukaran membuat konflik muncul setelah tindakan dimulai.

=== Kuasa dan Perbedaan Pendapat
<kuasa-dan-perbedaan-pendapat>
Kuasa berasal dari jabatan, keahlian, akses informasi, sumber daya, jaringan, atau kemampuan menolak. Fasilitator perlu mencegah keheningan dibaca sebagai persetujuan. Gunakan putaran bicara, masukan anonim bila aman, atau pertemuan terpisah untuk pihak yang sulit berbicara di ruang yang sama.

Perbedaan pendapat adalah data. Ia dapat mengungkap risiko, nilai yang terabaikan, atau bahasa yang tidak dipahami. Tanyakan, "Apa yang perlu benar agar Anda dapat menerima pilihan ini?" dan "Kondisi apa yang membuat pilihan ini tidak dapat diterima?"

=== Bahasa Bersama dan Peran Fasilitator
<bahasa-bersama-dan-peran-fasilitator>
Tim teknis berbicara tentang integrasi; keuangan tentang biaya; pengguna tentang kemudahan; regulator tentang kepatuhan. Fasilitator menerjemahkan tanpa menghapus perbedaan.

Perilaku fasilitator yang baik:

- mengatur giliran dan tujuan;
- memparafrasakan posisi serta kepentingan;
- memisahkan pribadi dari masalah;
- membuat konflik menjadi informasi;
- menanyakan suara yang belum terdengar;
- mencatat kesepakatan kecil;
- menguji pemahaman; dan
- tidak memaksakan solusi pribadi.

Fasilitator tidak harus netral terhadap keselamatan, martabat, atau kejujuran. Ia netral dalam memberi proses yang adil, bukan netral terhadap pelanggaran.

=== Opini yang Terbuka untuk Berubah
<opini-yang-terbuka-untuk-berubah>
Dalam #emph[Daya Tarik], opini dipahami sebagai perpaduan informasi, persepsi, perasaan, nilai, dan budaya; opini yang matang dapat digunakan sekaligus terbuka terhadap informasi baru @langi2025dayatarik. Sikap ini penting dalam negosiasi. Mengubah posisi karena bukti baru bukan kekalahan. Itu tanda bahwa perundingan menghasilkan pembelajaran.

=== AI sebagai Simulator Pihak
<ai-sebagai-simulator-pihak>
AI dapat mensimulasikan beberapa peran, menghasilkan alternatif, mendeteksi benturan syarat, atau menerjemahkan jargon. Tetapkan tujuan, pengetahuan, kendala, bahasa, dan wewenang tiap agen. Namun, agen AI bukan pribadi yang benar-benar menanggung akibat. Jangan menyerahkan nilai manusia, persetujuan, atau komitmen kritis kepadanya.

=== Praktis: Peta Banyak Pihak
<praktis-peta-banyak-pihak>
Lengkapi peta untuk kasus kantin:

#table(
  columns: (12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%),
  align: (auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header([Pihak], [Posisi], [Kepentingan], [Kendala], [Wewenang], [Wajib], [Diinginkan], [Tidak diterima],),
  table.hline(),
  [], [], [], [], [], [], [], [],
)
Kemudian hasilkan sedikitnya lima pilihan sebelum mengevaluasi. Tandai satu pertukaran dan satu risiko distribusi yang tidak adil.

=== Perform: Simulasi Negosiasi Banyak Pihak
<perform-simulasi-negosiasi-banyak-pihak>
Kelompok lima orang memainkan pelanggan/pengguna, penyedia, tim teknis, keuangan, dan pihak terdampak. Orang keenam menjadi fasilitator; pengamat mencatat jika kelompok lebih kecil.

Alur 20 menit:

+ setiap pihak menyatakan tujuan, kepentingan, kendala, dan wewenang;
+ fasilitator merumuskan masalah bersama;
+ kelompok menghasilkan pilihan tanpa menilai;
+ pilihan dibandingkan dan dipertukarkan;
+ syarat minimum diperiksa;
+ kesepakatan atau alasan belum sepakat ditulis.

Dokumen akhir memuat siapa, apa, kapan, syarat, bukti selesai, risiko, pihak yang menanggung, waktu tinjauan, dan mekanisme keberatan.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Pemetaan], [Hanya pihak berkuasa], [Semua pihak terdampak, termasuk suara lemah],
  [Kepentingan], [Posisi diperdebatkan], [Kepentingan dan kendala digali],
  [Pilihan], [Satu solusi dipaksakan], [Beberapa pilihan dan pertukaran dikembangkan],
  [Fasilitasi], [Giliran tidak seimbang], [Bahasa diterjemahkan dan perbedaan dirangkum],
  [Kesepakatan], [Kabur atau semu], [Dapat diterima, jelas, berwenang, dan dapat ditinjau],
  [Relasi], [Pemenang--pecundang], [Martabat, perbedaan, dan kerja sama berikutnya dijaga],
)
=== Refleksi
<refleksi-11>
+ Pihak mana yang hampir tidak terdengar?
+ Posisi apa yang berubah setelah kepentingannya dipahami?
+ Apakah ada "kesepakatan" dari keheningan semata?
+ Siapa menerima manfaat dan siapa menanggung risiko?
+ Apakah tidak sepakat lebih jujur daripada kesepakatan semu?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-12>
Negosiasi banyak pihak mempertemukan tujuan, kepentingan, kendala, nilai, kuasa, dan keadaan TAIDA yang berbeda. Komunikator memetakan pribadi, mencari kepentingan di balik posisi, menghasilkan pilihan sebelum menilai, menerjemahkan bahasa, melindungi suara berdaya rendah, dan merumuskan kesepakatan yang dapat diterima serta dilaksanakan.

#quote(block: true)[
#strong[Kesepakatan terbaik bukan yang membungkam perbedaan, melainkan yang membuat perbedaan dapat bekerja bagi tindakan bersama tanpa kehilangan martabat manusia.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-10>
Lihat #cite(<freeman1984strategic>, form: "prose"), #cite(<fisher2011getting>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

#heading(level: 1, numbering: none)[Bagian III --- Memperluas Lingkar Relasi]
<bagian-iii-memperluas-lingkar-relasi-1>
== Tetangga dan Komunitas: Bertindak Bersama di Tengah Perbedaan
<tetangga-dan-komunitas-bertindak-bersama-di-tengah-perbedaan>
#block[
#callout(
body: 
[
#strong[Kita tidak harus sepakat tentang segala hal untuk menyepakati sesuatu yang baik, adil, dan dapat dilakukan bersama.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-13>
Harta karun bab ini adalah kemampuan berkomunikasi melintasi perbedaan nilai, pengalaman, kepentingan, dan kuasa untuk menghasilkan tindakan kolektif yang dapat diterima. Keberhasilan tidak hanya diukur dari selesainya satu kegiatan, tetapi juga dari bertambahnya kapasitas komunitas untuk berbicara dan bekerja bersama pada masa depan.

=== Tujuan Belajar
<tujuan-belajar-12>
Pada akhir bab ini, Anda mampu:

- membedakan peran sebagai tetangga, warga, relawan, advokat, mediator, dan pemimpin komunitas;
- memisahkan fakta, interpretasi, nilai, dan posisi dalam konflik sosial;
- mengubah bingkai "orang melawan orang" menjadi "orang bersama-sama menghadapi masalah";
- membedakan konsensus, kesepakatan, partisipasi, koeksistensi, dan tindakan kolektif;
- memfasilitasi deliberasi yang memperhatikan suara minoritas dan perbedaan kuasa; serta
- menyusun #emph[Kesepakatan Komunitas] yang dapat ditinjau.

=== Kata Kunci
<kata-kunci-12>
#strong[Komunitas], #strong[kepentingan bersama], #strong[kepercayaan sosial], #strong[deliberasi], #strong[mediasi], #strong[pembingkaian ulang], #strong[konsensus], #strong[koeksistensi], #strong[partisipasi], #strong[kuasa], #strong[suara minoritas], dan #strong[tindakan kolektif].

=== Persiapan: Ruang yang Sama, Tujuan yang Berbeda
<persiapan-ruang-yang-sama-tujuan-yang-berbeda>
Bayangkan sebuah taman lingkungan. Anak-anak ingin bermain, remaja ingin berkumpul, lansia membutuhkan ketenangan, pedagang mencari penghasilan, orang tua memikirkan keselamatan, dan pengelola menghadapi anggaran terbatas.

Tuliskan satu kalimat tentang "masalah taman" dari sudut pandang setiap pihak. Apakah Anda masih yakin hanya ada satu versi masalah?

=== Attention: Jalan yang Tidak Ditempuh Sendirian
<attention-jalan-yang-tidak-ditempuh-sendirian>
Perjalanan studi saya sering diceritakan sebagai impian seorang anak Tomohon yang akhirnya tiba di luar negeri. Namun, jika hanya tokoh utama yang terlihat, ceritanya menjadi tidak lengkap. Ada ayah yang mengirim kartu pos, Ina yang berjalan bersama saya, keluarga yang memberi dukungan, para mentor di ITB dan PAU Mikroelektronika, instruktur bahasa, WUSC, program beasiswa, profesor yang menerima, serta rekan yang lebih dahulu membangun reputasi.

Tidak seorang pun dari mereka melakukan seluruh pekerjaan. Namun, jaringan relasi membuat jalan yang tidak mungkin ditempuh sendirian menjadi terbuka.

#block[
#callout(
body: 
[
Komunitas bukan latar belakang pasif bagi keberhasilan individu. Komunitas adalah kumpulan pribadi yang saling membuka kemungkinan, menanggung sebagian beban, dan mewariskan kepercayaan. Karena itu, keberhasilan pribadi membawa tanggung jawab untuk kembali menyumbang.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Komunitas Tetap Dimulai dari Pribadi
<interest-komunitas-tetap-dimulai-dari-pribadi>
Istilah "warga", "masyarakat", atau "komunitas" mudah membuat manusia menghilang di balik kategori. Padahal setiap orang hadir dalam peran dan pengalaman berbeda. Orang yang sama dapat menjadi orang tua, pemilik usaha, relawan, penyandang disabilitas, penyewa rumah, atau pengurus lingkungan.

Komunitas adalah sistem relasi yang memiliki ingatan. Janji yang ditepati, pembagian bantuan yang adil, dan ruang bicara yang aman membentuk kepercayaan. Sebaliknya, keputusan tertutup dan pengalaman diabaikan menimbulkan kecurigaan yang terbawa ke persoalan berikutnya. Modal sosial---jaringan, norma timbal balik, dan kepercayaan---membantu orang bertindak bersama @putnam2000bowling.

=== Desire: Dari Konflik Pribadi menuju Masalah Bersama
<desire-dari-konflik-pribadi-menuju-masalah-bersama>
Konflik sering menggabungkan empat lapisan:

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Lapisan], [Pertanyaan], [Contoh],),
  table.hline(),
  [Fakta], [Apa yang dapat diamati?], [Musik berlangsung pukul 21.00--23.00 pada tiga malam.],
  [Interpretasi], [Apa makna yang diberikan?], [Pengelola tidak peduli pada warga.],
  [Nilai], [Apa yang dianggap penting?], [Istirahat, ekspresi anak muda, mata pencaharian.],
  [Posisi], [Apa yang dituntut?], [Tutup kegiatan malam.],
)
Kesepakatan pada fakta tidak otomatis menghasilkan kesepakatan pada makna. Namun, pemisahan lapisan mencegah interpretasi diperlakukan sebagai bukti tentang watak orang lain.

- Bingkai serangan: "Pedagang dan pengunjung merusak ketertiban."
- Bingkai masalah bersama: "Bagaimana menjaga mata pencaharian dan ruang berkumpul sambil melindungi waktu istirahat serta keselamatan warga?"

Pembingkaian ulang tidak menghapus pertentangan. Ia mengubah pertentangan menjadi pertanyaan yang dapat dikerjakan bersama.

=== Dari Debat menuju Deliberasi
<dari-debat-menuju-deliberasi>
Debat cenderung mencari argumen pemenang. Deliberasi mencari pemahaman yang cukup untuk memilih tindakan bersama. Dalam deliberasi, peserta:

+ mendengar pengalaman sebelum membantah;
+ menyatakan kepentingan dan batas;
+ memeriksa fakta serta ketidakpastian;
+ menghasilkan lebih dari dua pilihan;
+ menilai dampak pada pihak yang berbeda; dan
+ menetapkan cara belajar dari tindakan.

Pengelolaan sumber daya bersama memerlukan aturan yang dipahami, partisipasi pihak terdampak, pemantauan, dan mekanisme penyelesaian konflik @ostrom1990governing. Prinsip itu berlaku lebih luas: tindakan kolektif bertahan ketika orang dapat melihat prosesnya adil dan dapat diperbaiki.

=== Konsensus Tidak Selalu Diperlukan
<konsensus-tidak-selalu-diperlukan>
- #strong[Konsensus:] semua pihak menerima satu pandangan atau keputusan.
- #strong[Kesepakatan:] pihak-pihak menerima tindakan dan syarat tertentu meski alasan berbeda.
- #strong[Partisipasi:] seseorang terlibat dalam proses atau tindakan.
- #strong[Koeksistensi:] pihak yang berbeda dapat hidup berdampingan dengan batas yang jelas.
- #strong[Tindakan kolektif:] beberapa pihak mengoordinasikan kontribusi untuk hasil bersama.

Komunitas sering membutuhkan #strong[kesepakatan yang cukup] untuk bertindak, bukan keseragaman keyakinan. Namun, suara mayoritas tidak selalu cukup. Jika manfaat dinikmati banyak orang sementara beban berat ditanggung kelompok kecil, keadilan perlu diperiksa.

=== Kuasa, Keheningan, dan Partisipasi
<kuasa-keheningan-dan-partisipasi>
Kehadiran di rapat tidak sama dengan partisipasi; keheningan tidak sama dengan persetujuan. Perbedaan pendidikan, jabatan, bahasa, usia, akses teknologi, dan pengalaman diskriminasi memengaruhi siapa yang dapat berbicara.

Fasilitator dapat:

- menjelaskan tujuan dan aturan percakapan;
- memberi giliran yang seimbang;
- menerima masukan tertulis atau anonim;
- memparafrasakan secara adil;
- mengundang pihak yang belum terdengar;
- membedakan serangan dari keberatan;
- mencatat wilayah sepakat dan belum sepakat; serta
- memastikan tidak ada janji dibuat tanpa kewenangan.

Fasilitator menjaga proses yang adil. Ia tidak netral terhadap kekerasan, penghinaan, atau penghilangan hak.

=== TAIDA untuk Tindakan Komunitas
<taida-untuk-tindakan-komunitas>
- #strong[Sasaran:] siapa terdampak, berwenang, mengerjakan, atau berpotensi terabaikan?
- #strong[Perhatian:] bagaimana masalah dibuat terlihat tanpa menyalahkan kelompok?
- #strong[Minat:] mengapa isu ini relevan bagi kepentingan yang berbeda?
- #strong[Keinginan:] keadaan bersama apa yang cukup bernilai bagi masing-masing pihak?
- #strong[Tindakan:] siapa berbuat apa, kapan, dengan sumber daya dan tinjauan apa?

Tidak semua pihak berada pada keadaan yang sama. Warga mungkin siap bertindak, sedangkan pengelola baru mengakui adanya masalah. Komunikator juga harus bersedia berubah ketika mendengar informasi baru.

=== Pilot sebagai Kesepakatan untuk Belajar
<pilot-sebagai-kesepakatan-untuk-belajar>
Ketika pihak berbeda memprediksi akibat yang berbeda, uji coba terbatas dapat mengubah perdebatan menjadi pembelajaran. Tetapkan durasi, ukuran keberhasilan, perlindungan risiko, pihak pemantau, dan keputusan setelah uji coba. Pilot bukan cara menyelundupkan keputusan permanen.

Nilai dua hasil:

- #strong[hasil kolektif:] apakah masalah berkurang?;
- #strong[kapasitas relasi:] apakah komunitas lebih mampu berbicara dan bertindak bersama?

=== AI dalam Komunikasi Komunitas
<ai-dalam-komunikasi-komunitas>
AI dapat membantu merangkum masukan, menerjemahkan bahasa, memetakan pilihan, atau meninjau rancangan kesepakatan. Simulasi AI bukan konsultasi publik. Data minoritas yang sedikit tidak berarti kebutuhannya tidak penting. Transparansikan penggunaan AI, minimalkan data pribadi, dan berikan cara manusia memeriksa serta membantah ringkasan.

=== Praktis: Mengubah Serangan Menjadi Masalah Bersama
<praktis-mengubah-serangan-menjadi-masalah-bersama>
Ubah pernyataan berikut:

#quote(block: true)[
"Anak muda sekarang tidak tahu aturan dan selalu membuat lingkungan kacau."
]

Pisahkan fakta, interpretasi, nilai, dan posisi. Buat tiga bingkai masalah bersama. Kemudian hasilkan sedikitnya lima pilihan, termasuk satu uji coba.

=== Perform: Deliberasi Komunitas
<perform-deliberasi-komunitas>
Simulasikan konflik penggunaan taman dengan sedikitnya empat peran dan seorang fasilitator. Hasilkan #emph[Kesepakatan Komunitas] yang memuat:

- fakta yang disepakati dan yang masih diperdebatkan;
- kepentingan serta batas tiap pihak;
- pilihan yang dipertimbangkan;
- keputusan atau alasan belum sepakat;
- tindakan, penanggung jawab, tenggat, dan sumber daya;
- perlindungan bagi pihak yang menanggung risiko; serta
- waktu dan ukuran evaluasi.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Pemetaan pihak], [Hanya pihak dominan], [Pihak terdampak dan suara minoritas terwakili],
  [Pembingkaian], [Orang melawan orang], [Orang bersama menghadapi masalah],
  [Deliberasi], [Saling membantah], [Mendengar, memeriksa, dan menghasilkan pilihan],
  [Kesepakatan], [Mayoritas tanpa syarat], [Dapat diterima, jelas, dan dapat ditinjau],
  [Hasil relasi], [Ketegangan diabaikan], [Kepercayaan dan kapasitas bersama dinilai],
)
=== Refleksi
<refleksi-12>
+ Suara siapa yang paling mudah saya abaikan?
+ Interpretasi apa yang saya perlakukan sebagai fakta?
+ Apakah "kepentingan bersama" membagi manfaat dan beban secara adil?
+ Di mana konsensus tidak diperlukan, dan di mana persetujuan wajib diperlukan?
+ Apakah proses ini membuat komunitas lebih mampu menghadapi persoalan berikutnya?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-13>
Komunitas adalah sistem relasi yang memiliki ingatan. Komunikasi komunitas memisahkan fakta, interpretasi, nilai, dan posisi; membingkai ulang konflik sebagai masalah bersama; mengadakan deliberasi; melindungi suara yang kurang berkuasa; serta mengubah kesepakatan menjadi tindakan yang dapat ditinjau. Kita tidak harus sepakat tentang segala hal untuk hidup berdampingan dan melakukan sesuatu yang baik bersama.

#quote(block: true)[
#strong[Tindakan kolektif yang sehat menghasilkan perubahan sekaligus memperbesar kemampuan komunitas untuk saling mempercayai.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-11>
Lihat #cite(<ostrom1990governing>, form: "prose"), #cite(<putnam2000bowling>, form: "prose"), #cite(<fisher2011getting>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== Berkomunikasi dengan Dunia
<berkomunikasi-dengan-dunia>
#block[
#callout(
body: 
[
#strong[Satu suara dapat menjangkau ribuan orang dalam beberapa detik. Tantangannya bukan sekadar memperluas jangkauan, melainkan menyumbangkan makna tanpa berubah menjadi kebisingan.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-14>
Harta karun bab ini adalah kemampuan menyampaikan satu gagasan kepada publik melalui medium dan bahasa berbeda dengan tetap menjaga ketepatan, tanggung jawab, serta suara autentik. Ukurannya bukan hanya jumlah tayangan, tetapi apa yang dipahami, dipercaya, dipertimbangkan, atau dilakukan secara bertanggung jawab.

=== Tujuan Belajar
<tujuan-belajar-13>
Pada akhir bab ini, Anda mampu:

- memilih peran publik dan tujuan komunikasi yang bertanggung jawab;
- mengenali audiens terbayang, keruntuhan konteks, dan risiko reputasi;
- mengolah kisah, fakta, konsep, dan opini menjadi kontribusi publik;
- membedakan penyederhanaan dari distorsi;
- menyesuaikan satu makna untuk beberapa medium;
- menilai jangkauan, dampak, akurasi, hak cipta, dan respons; serta
- menghasilkan portofolio #emph[Satu Gagasan, Empat Bahasa Publik].

=== Kata Kunci
<kata-kunci-13>
#strong[Publik], #strong[audiens terbayang], #strong[keruntuhan konteks], #strong[reputasi], #strong[narasi publik], #strong[jangkauan], #strong[dampak], #strong[penyederhanaan], #strong[distorsi], #strong[akurasi], #strong[hak cipta], #strong[koreksi publik], dan #strong[suara autentik].

=== Persiapan: Jika Pesan Anda Keluar dari Ruangan
<persiapan-jika-pesan-anda-keluar-dari-ruangan>
Ambil satu pesan yang pernah Anda kirim kepada kelompok kecil. Bayangkan pesan itu dipotong, diambil tangkapan layarnya, lalu dibaca oleh dosen, keluarga, calon pemberi kerja, dan orang yang tidak mengenal Anda. Bagian mana yang kehilangan konteks? Apa yang tetap dapat Anda pertanggungjawabkan?

=== Attention: Lampu-Lampu Los Angeles
<attention-lampu-lampu-los-angeles>
Pada 13 Desember 1989, pesawat yang saya tumpangi mendekati Los Angeles. Dari jendela terlihat lampu kota membentang hingga kaki langit. Bagi orang lain, itu mungkin pemandangan malam biasa. Bagi saya, ia adalah pertemuan antara impian seorang anak kelas dua di Tomohon dan kenyataan yang akhirnya tiba setelah bertahun-tahun.

Kisah itu personal: ada ayah, kartu pos Golden Gate, perjuangan bahasa, penolakan, keluarga, dan keberangkatan yang hampir tertunda. Namun, ketika diceritakan, maknanya dapat menjadi universal: impian, ketekunan, pertolongan orang lain, dan rasa syukur.

#block[
#callout(
body: 
[
Pengalaman pribadi menjadi kontribusi publik ketika ia tidak berhenti pada "lihatlah saya", tetapi membantu orang lain melihat hidupnya sendiri dengan cara baru.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Apa yang Berubah Ketika Skala Membesar?
<interest-apa-yang-berubah-ketika-skala-membesar>
Di ruang publik, kita tidak mengenal semua orang. Pesan dapat bertahan, disalin, dipotong, diterjemahkan, dan dibawa ke konteks yang tidak kita bayangkan. Media sosial mempertemukan keluarga, teman, kolega, dan orang asing dalam satu audiens yang runtuh batas-batas konteksnya @marwick2011tweet.

Karena itu, kenali publik pada tiga tingkat:

+ #strong[publik umum:] kebutuhan akses dan bahasa luas;
+ #strong[peran atau konteks:] mahasiswa, orang tua, praktisi, pengambil kebijakan;
+ #strong[pribadi individual:] interaksi lanjutan yang memerlukan persetujuan dan data lebih spesifik.

Personalisasi tidak membenarkan pengawasan. Kita boleh menyesuaikan pesan berdasarkan kebutuhan yang wajar tanpa mengumpulkan rincian pribadi secara berlebihan.

=== Desire: Peran dan Tujuan Publik
<desire-peran-dan-tujuan-publik>
Satu pribadi dapat hadir sebagai penulis, ilmuwan, pendidik, seniman, wirausahawan, warga, pemimpin publik, atau pembuat konten. Peran menentukan tanggung jawab.

Tujuan publik dapat berupa:

- memberi informasi;
- membantu memahami;
- mengundang refleksi;
- membagikan pembelajaran;
- mendorong adopsi;
- mengajak partisipasi; atau
- menggerakkan tindakan.

Tayangan bukan tujuan otomatis. "Menjadi viral" tidak menjelaskan nilai bagi publik. Rumuskan perubahan utama yang diharapkan dan satu tindakan primer yang masuk akal.

=== Empat Pesan untuk Publik
<empat-pesan-untuk-publik>
#emph[Daya Tarik] menekankan pesan verbal yang disiapkan dengan baik: kisah pengalaman, kisah inspiratif berbasis fakta, konsep yang mencerdaskan, dan opini yang berpengaruh @langi2025dayatarik.

==== Kisah Pengalaman
<kisah-pengalaman>
Bangun narasi: pribadi → situasi → tantangan → pilihan → konsekuensi → makna. Lindungi privasi orang yang ikut berada dalam cerita.

==== Kisah Inspiratif Berbasis Fakta
<kisah-inspiratif-berbasis-fakta-1>
Gunakan data dan sumber yang dapat diperiksa. Bedakan fakta, interpretasi, dan dramatisasi. Cerita membuat bukti dapat dirasakan, tetapi tidak menggantikan bukti.

==== Konsep yang Mencerdaskan
<konsep-yang-mencerdaskan-1>
Konsep menamai pola. Pilih tingkat abstraksi yang cukup luas untuk berguna dan cukup spesifik untuk ditindaklanjuti. Jelaskan contoh, batas, serta pengecualian.

==== Opini yang Berpengaruh
<opini-yang-berpengaruh-1>
Nyatakan posisi, alasan, bukti, nilai, dan sudut pandang. Opini matang terbuka terhadap informasi baru. Berpengaruh tidak sama dengan memancing kemarahan untuk memperoleh keterlibatan.

=== Kreativitas: Kemungkinan, Alternatif, dan Koneksi
<kreativitas-kemungkinan-alternatif-dan-koneksi>
Informasi tidak biasa dapat memperoleh perhatian. Pertanyaan "bagaimana jika" membuka kemungkinan. Perbandingan dan koneksi membantu publik melihat hubungan baru. Namun, kreativitas perlu pagar:

- spekulasi diberi label sebagai spekulasi;
- alternatif tidak dipresentasikan sebagai kepastian;
- analogi disertai batas;
- keterkejutan tidak dibeli dengan ketidakakuratan.

=== Bahasa Publik Berlapis
<bahasa-publik-berlapis>
Susun pesan dalam lapisan:

+ #strong[judul:] tepat dan menarik tanpa menipu;
+ #strong[ringkasan:] makna inti dan relevansi;
+ #strong[penjelasan:] mekanisme, konteks, dan contoh;
+ #strong[bukti:] sumber, data, dan ketidakpastian;
+ #strong[rincian teknis:] metode serta bahan pemeriksaan.

Penyederhanaan mengurangi beban bahasa sambil mempertahankan struktur kebenaran. Distorsi menghapus syarat, risiko, atau konteks yang dapat mengubah kesimpulan.

=== Medium Mengubah Pengalaman
<medium-mengubah-pengalaman>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Medium], [Kekuatan], [Risiko], [Pemeriksaan],),
  table.hline(),
  [Pidato], [kehadiran, suara, dan emosi], [cepat berlalu], [apakah inti dapat diingat?],
  [Artikel], [kedalaman dan rujukan], [beban baca], [apakah struktur membantu pembaca?],
  [Poster/visual], [pola terlihat cepat], [penyederhanaan berlebih], [apakah skala dan sumber jelas?],
  [Video], [demonstrasi dan kedekatan], [penyuntingan manipulatif], [apakah potongan mewakili konteks?],
  [Media sosial], [jangkauan dan dialog], [keruntuhan konteks], [apakah tetap bertanggung jawab jika dipisahkan?],
  [Situs web], [lapisan dan pembaruan], [informasi usang], [apakah tanggal serta koreksi terlihat?],
)
Pesan nonverbal---wajah, nada, musik, warna, tata letak---adalah kemasan yang memengaruhi penerimaan. Kemasan harus membantu akses, bukan menyamarkan isi yang rapuh.

=== Jangkauan dan Dampak
<jangkauan-dan-dampak>
- #strong[Jangkauan:] berapa orang berpotensi melihat?
- #strong[Perhatian:] berapa yang berhenti dan mengakses?
- #strong[Pemahaman:] apa yang mereka tangkap?
- #strong[Kepercayaan:] apakah sumber dianggap layak?
- #strong[Tindakan:] apa yang dilakukan?
- #strong[Dampak relasional:] apakah dialog dan reputasi membaik atau rusak?

Gabungkan data kuantitatif dengan umpan balik kualitatif. Viralitas dapat berarti salah paham. Respons negatif dapat memuat koreksi yang berharga.

=== Tanggung Jawab Publik
<tanggung-jawab-publik>
Sebelum menerbitkan, periksa:

- fakta dan sumber;
- perbedaan fakta, interpretasi, nilai, serta rekomendasi;
- izin, atribusi, dan hak cipta;
- privasi dan keamanan pihak yang disebut;
- ketidakpastian;
- kelompok yang mungkin dirugikan;
- kemungkinan pesan dipotong dari konteks.

Jika salah, koreksi secara terlihat: sebutkan apa yang keliru, berikan informasi benar, jelaskan dampak, dan perbarui artefak. Reputasi bukan popularitas; reputasi adalah ingatan publik tentang kompetensi, kejujuran, kejelasan, kepedulian, dan akuntabilitas.

=== AI dalam Komunikasi Publik
<ai-dalam-komunikasi-publik>
AI dapat membantu riset awal, organisasi, penerjemahan, adaptasi format, pemeriksaan ambiguitas, dan aksesibilitas. AI juga dapat menghasilkan kebisingan dalam skala besar. Verifikasi klaim, periksa sumber, hormati hak cipta, nyatakan penggunaan AI bila material, dan pertahankan keputusan editorial manusia.

=== Praktis: Satu Makna, Empat Bentuk
<praktis-satu-makna-empat-bentuk>
Pilih satu gagasan yang Anda kuasai. Rumuskan makna inti, bukti utama, ketidakpastian, dan tindakan yang diharapkan. Buat:

+ pernyataan 30 detik;
+ penjelasan tiga menit;
+ ringkasan profesional 200 kata; dan
+ satu penjelasan visual dengan teks alternatif.

=== Perform: Satu Gagasan, Empat Bahasa Publik
<perform-satu-gagasan-empat-bahasa-publik>
Portofolio memuat keempat artefak, profil audiens terbayang, peta TAIDA, sumber, catatan hak cipta, uji pemahaman, simulasi keruntuhan konteks, serta refleksi respons.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Makna inti], [Berubah antarformat], [Konsisten dan sesuai bukti],
  [Bahasa publik], [Jargon atau sensasional], [Jelas, berlapis, dan relevan],
  [Adaptasi medium], [Isi disalin mentah], [Kekuatan medium digunakan secara tepat],
  [Tanggung jawab], [Sumber/konteks kabur], [Akurasi, atribusi, privasi, dan risiko diperiksa],
  [Dampak], [Hanya menghitung tayangan], [Pemahaman, tindakan, dan relasi dinilai],
)
=== Refleksi
<refleksi-13>
+ Siapa yang sungguh membutuhkan gagasan ini?
+ Apa yang saya ketahui, tafsirkan, dan nilai?
+ Apakah judul menjanjikan sesuatu yang diberikan isi?
+ Bagaimana pesan dapat disalahpahami ketika keluar dari konteks?
+ Apakah saya menambah sinyal yang bernilai atau kebisingan?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-14>
Komunikasi dengan dunia adalah kontribusi kepada pribadi-pribadi yang sebagian besar tidak kita kenal. Komunikator memilih peran dan tujuan, membangun pesan melalui kisah, fakta, konsep, atau opini, menyederhanakan tanpa mendistorsi, menyesuaikan medium, serta menjaga akurasi, hak cipta, privasi, dan akuntabilitas. Keberhasilan diukur dari dampak, bukan jangkauan semata.

#quote(block: true)[
#strong[Suara publik yang bernilai tidak hanya terdengar; ia membantu orang memahami, menilai, dan bertindak tanpa kehilangan kebebasan serta martabat.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-12>
Lihat #cite(<marwick2011tweet>, form: "prose"), #cite(<heath2007made>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

== Komunikasi Berpusat pada Manusia di Era AI
<komunikasi-berpusat-pada-manusia-di-era-ai>
#block[
#callout(
body: 
[
#strong[AI dapat menyusun kata, menerjemahkan, merangkum, dan menjalankan tugas terbatas. Namun, manusia tetap memiliki tujuan, relasi, kewenangan moral, serta tanggung jawab atas akibat komunikasi.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-15>
Harta karun bab ini adalah kemampuan memilih peran AI yang proporsional, menetapkan batas kewenangan, melindungi privasi, memeriksa kebenaran, dan mempertahankan kepemilikan manusia atas relasi. Anda berhasil apabila dapat merancang kopilot komunikasi yang membantu tanpa menyamar, mengeksploitasi, atau mengambil keputusan yang seharusnya tetap manusiawi.

=== Tujuan Belajar
<tujuan-belajar-14>
Pada akhir bab ini, Anda mampu:

- membedakan AI sebagai cermin, pelatih, penerjemah, kopilot, mediator, dan agen terdelegasi;
- memilih tingkat keterlibatan AI sebelum, selama, atau sesudah komunikasi;
- membedakan komunikasi pembawa tugas dari komunikasi pembawa relasi;
- menetapkan tujuan, data, batas kewenangan, kondisi eskalasi, dan tinjauan manusia;
- menilai risiko kekeliruan, bias, profilisasi, manipulasi, ketergantungan, privasi, dan hilangnya suara autentik; serta
- menghasilkan spesifikasi kopilot komunikasi untuk salah satu domain kehidupan.

=== Kata Kunci
<kata-kunci-14>
#strong[Komunikasi bermediasi AI], #strong[cermin], #strong[pelatih], #strong[penerjemah], #strong[kopilot], #strong[mediator], #strong[delegasi terbatas], #strong[kesadaran konteks], #strong[memori relasi], #strong[persetujuan], #strong[privasi], #strong[otonomi], #strong[bias], #strong[tinjauan manusia], #strong[batas kewenangan], dan #strong[akuntabilitas].

=== Persiapan: Siapa yang Sebenarnya Berbicara?
<persiapan-siapa-yang-sebenarnya-berbicara>
Bayangkan Anda menerima permintaan maaf yang sepenuhnya dibuat dan dikirim AI tanpa dibaca pengirim. Apakah kata-katanya dapat benar? Apakah permintaan maaf itu sungguh milik pengirim? Apa yang hilang?

Tuliskan satu tugas komunikasi yang dengan nyaman Anda bantu menggunakan AI dan satu tugas yang tidak ingin Anda delegasikan. Jelaskan perbedaannya.

=== Attention: Teknologi Memperluas, Bukan Menghapus, Tanggung Jawab
<attention-teknologi-memperluas-bukan-menghapus-tanggung-jawab>
Sebagai orang yang tumbuh dari pendidikan teknik dan kemudian mengajar, saya tertarik pada alat yang memperluas kemampuan manusia. Bahasa Inggris pernah menjadi teknologi sosial yang membuka akses saya ke komunitas akademik yang lebih luas. Pesawat membawa saya melintasi samudra. Surat, lembaga, dan jaringan informasi menghubungkan orang-orang yang berjauhan.

Namun, alat tidak menjalani relasi atas nama kita. Ketika saya memutuskan mendampingi Ina dan menunggu kelahiran Gladys, tidak ada teknologi yang dapat menggantikan kehadiran itu. Ketika orang lain mempercayai dan membantu perjalanan saya, tanggung jawab untuk menghargai kepercayaan tetap berada pada manusia.

#block[
#callout(
body: 
[
Teknologi yang baik mengurangi hambatan agar manusia dapat memahami dan melayani dengan lebih baik. Ia tidak boleh menjadi alasan untuk menghilang dari percakapan yang justru menuntut kehadiran kita.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Interest: Kecerdasan Sistem, Relasi Milik Pribadi
<interest-kecerdasan-sistem-relasi-milik-pribadi>
AI dapat menghasilkan pola bahasa yang tampak empatik, tetapi tidak memiliki sejarah relasi, tubuh yang menanggung akibat, atau komitmen moral seperti manusia. Karena itu, prinsip utama bab ini ialah:

#quote(block: true)[
#strong[Kecerdasan dapat tersebar dalam sistem; relasi dan tanggung jawab tetap dimiliki pribadi.]
]

Kerangka etika AI menekankan manfaat, pencegahan bahaya, otonomi, keadilan, dan keterjelasan @floridi2018ai4people. Rekomendasi UNESCO menempatkan martabat, hak asasi, keberagaman, transparansi, dan pengawasan manusia sebagai perhatian penting @unesco2021ethics. Dalam praktik komunikasi, prinsip tersebut perlu diterjemahkan menjadi keputusan konkret tentang data, peran, dan kewenangan.

=== Desire: Enam Peran AI
<desire-enam-peran-ai>
==== Cermin
<cermin>
AI membantu memisahkan fakta dan interpretasi, menemukan asumsi, atau mengajukan pertanyaan reflektif. Cermin tidak mendiagnosis identitas dan tidak menentukan pilihan akhir.

==== Pelatih
<pelatih>
AI mensimulasikan percakapan, memberi umpan balik pada nada, dan menghasilkan variasi pertanyaan. Pelatih membantu berlatih; manusia tetap melakukan percakapan nyata.

==== Penerjemah
<penerjemah>
AI menyesuaikan bahasa teknis, tingkat kerumitan, medium, atau bahasa alami. Penerjemahan harus mempertahankan fakta, risiko, serta suara penulis.

==== Kopilot
<kopilot>
AI membantu selama alur kerja: menyiapkan agenda, mencatat, merangkum, menandai keputusan, atau menyarankan pertanyaan. Kopilot memberi dukungan; manusia mengarahkan, memeriksa, dan menyetujui.

==== Mediator
<mediator>
AI dapat merangkum posisi, mencari kesamaan, atau mengubah serangan menjadi rumusan masalah. Penggunaannya perlu transparan. AI tidak menentukan keadilan, memaksa kompromi, atau menggantikan mediator manusia pada situasi berisiko tinggi.

==== Agen Terdelegasi
<agen-terdelegasi>
AI menjalankan tugas komunikasi dalam wilayah kewenangan yang telah ditetapkan, misalnya menawarkan slot jadwal atau menjawab pertanyaan rutin. Delegasi memerlukan batas nilai, biaya, waktu, data, gaya bahasa, kondisi berhenti, dan eskalasi.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Peran AI], [Kewenangan wajar], [Contoh batas],),
  table.hline(),
  [Cermin], [menghasilkan pertanyaan], [tidak mendiagnosis pribadi],
  [Pelatih], [memberi simulasi dan umpan balik], [tidak mengirim pesan],
  [Penerjemah], [membuat versi bahasa], [tidak mengubah risiko material],
  [Kopilot], [menyarankan dan merangkum], [manusia menyetujui keluaran],
  [Mediator], [memetakan perbedaan], [tidak menetapkan hasil adil],
  [Agen], [bertindak dalam aturan], [eskalasi untuk pengecualian/komitmen baru],
)
=== Tiga Tingkat Keterlibatan
<tiga-tingkat-keterlibatan>
+ #strong[Persiapan:] AI digunakan sebelum komunikasi. Risiko relatif lebih rendah karena keluaran dapat diperiksa.
+ #strong[Pendampingan:] AI hadir selama atau sesudah komunikasi. Transparansi, persetujuan, dan ketepatan ringkasan menjadi penting.
+ #strong[Delegasi terbatas:] AI bertindak tanpa persetujuan per pesan di dalam batas. Risiko tertinggi karena kesalahan langsung memengaruhi orang lain.

Aturan sederhana: semakin sulit tindakan dibalik, semakin besar dampak relasional, semakin sensitif data, dan semakin tinggi risiko, semakin kuat kebutuhan akan keputusan manusia.

=== Pembawa Tugas dan Pembawa Relasi
<pembawa-tugas-dan-pembawa-relasi>
- #strong[Komunikasi pembawa tugas:] penjadwalan, pengingat administratif, status pengiriman, atau informasi rutin.
- #strong[Komunikasi pembawa relasi:] permintaan maaf, ungkapan kasih, kabar duka, pemecatan, penilaian kinerja, konflik keluarga, dan keputusan yang menyentuh martabat.

AI lebih mudah didelegasikan pada tugas yang dapat dibalik, beraturan jelas, dan berdampak relasional rendah. AI dapat membantu menyiapkan komunikasi pembawa relasi, tetapi manusia perlu hadir, menyatakan kepemilikan, mendengar respons, dan menanggung konsekuensi.

AI tidak dapat meminta maaf dalam arti penuh atas kesalahan saya. Ia dapat membantu saya menemukan kata, tetapi saya yang perlu mengatakan, mengakui, memperbaiki, dan berubah.

=== AI dalam Lima Domain
<ai-dalam-lima-domain>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Domain], [Manfaat], [Pagar utama],),
  table.hline(),
  [Diri], [jurnal, pertanyaan, latihan], [privasi dan ketergantungan],
  [Keluarga/sahabat], [tinjauan nada, perspektif], [keaslian dan rahasia orang lain],
  [Profesional], [ringkasan, penerjemahan, koordinasi], [kerahasiaan, akurasi, wewenang],
  [Komunitas], [pengelompokan masukan, akses bahasa], [bias representasi dan transparansi],
  [Dunia], [adaptasi format, aksesibilitas, riset awal], [skala kesalahan, hak cipta, kebisingan],
)
=== AI dan TAIDA
<ai-dan-taida>
AI dapat membantu memetakan sasaran, membuat pembuka, meninjau relevansi, menjelaskan manfaat, serta merumuskan langkah. Namun, prediksi keadaan TAIDA tidak pernah pasti. Tatapan, riwayat klik, atau nada pesan bukan izin untuk menyimpulkan kerentanan dan mengeksploitasinya.

Pengetahuan tentang pribadi hanya boleh digunakan untuk meningkatkan pemahaman dan nilai bersama, bukan untuk menekan kelemahan. Personalisasi etis memberi manfaat yang dapat dipahami, pilihan, dan kontrol. Personalisasi manipulatif menyembunyikan cara data digunakan dan mengoptimalkan kepatuhan.

=== Kesadaran Konteks dan Memori Relasi
<kesadaran-konteks-dan-memori-relasi>
AI bekerja lebih baik dengan konteks, tetapi setiap konteks tambahan menambah kewajiban perawatan. Memori relasi dapat mencegah pengulangan dan membantu kontinuitas. Ia juga dapat berubah menjadi pengawasan.

Tanyakan:

- data apa yang benar-benar diperlukan?;
- siapa pemilik dan siapa yang dapat mengakses?;
- berapa lama disimpan?;
- dapatkah seseorang melihat, memperbaiki, dan menghapus?;
- apakah data diperoleh dengan persetujuan yang bermakna?;
- apa akibat jika bocor atau disalahartikan?

Prinsip minimisasi: kumpulkan dan bagikan sesedikit mungkin data yang tetap memungkinkan tujuan tercapai.

=== Tujuh Risiko Utama
<tujuh-risiko-utama>
+ #strong[Kekeliruan:] keluaran lancar dapat salah atau mengarang sumber.
+ #strong[Bias:] pola data dapat merugikan kelompok tertentu.
+ #strong[Profilisasi:] dugaan tentang pribadi diperlakukan sebagai fakta.
+ #strong[Manipulasi:] personalisasi mengeksploitasi emosi atau kerentanan.
+ #strong[Hilangnya keaslian:] suara manusia diganti bahasa generik atau penyamaran.
+ #strong[Ketergantungan:] kemampuan bertanya, menulis, atau menghadapi konflik melemah.
+ #strong[Kesalahan kewenangan:] AI menjanjikan, mengungkap, atau memutuskan di luar mandat.

Kerangka Manajemen Risiko AI NIST mengorganisasi pengelolaan risiko melalui fungsi tata kelola, pemetaan, pengukuran, dan pengelolaan @nist2023airmf. Untuk komunikasi, artinya: tentukan siapa bertanggung jawab, pahami konteks dan dampak, uji kualitas, lalu kelola serta pantau penggunaan.

=== Tumpukan Tanggung Jawab
<tumpukan-tanggung-jawab>
==== AI dapat:
<ai-dapat>
- menghasilkan, mengelompokkan, menerjemahkan, dan menyarankan;
- menyatakan ketidakpastian jika dirancang demikian;
- mencatat jejak proses.

==== Manusia harus:
<manusia-harus>
- menentukan tujuan dan nilai;
- memastikan dasar hukum serta persetujuan;
- memeriksa fakta dan bias;
- menetapkan kewenangan;
- menyetujui komunikasi material;
- menyediakan cara banding dan koreksi;
- menanggung tanggung jawab atas akibat.

"Human-in-the-loop" bukan sekadar tombol persetujuan. Peninjau harus mempunyai waktu, informasi, kompetensi, dan kewenangan nyata untuk menolak.

=== Prompt Berpusat pada Pribadi
<prompt-berpusat-pada-pribadi>
Sebuah prompt kerja dapat memuat:

- pribadi/peran yang dihadapi tanpa data berlebihan;
- relasi dan konteks;
- tujuan yang bertanggung jawab;
- keadaan komunikasi saat ini;
- makna inti dan bukti;
- bahasa serta medium;
- batas, hal yang tidak boleh dilakukan, dan ketidakpastian;
- format keluaran;
- bagian yang wajib diperiksa manusia.

Contoh:

#quote(block: true)[
"Bantu saya menyiapkan tiga pertanyaan untuk rekan yang terlambat menyelesaikan tugas. Tujuan saya memahami hambatan dan membuat kesepakatan. Jangan menebak kepribadian atau niatnya. Hindari bahasa menuduh. Tandai informasi yang perlu saya tanyakan langsung. Jangan mengirim pesan."
]

AI memperkuat bingkai pengguna. Prompt manipulatif akan menghasilkan komunikasi manipulatif yang lebih efisien. Karena itu, mutu pertanyaan manusia tetap menentukan.

=== Praktis: Memilih Tingkat Bantuan
<praktis-memilih-tingkat-bantuan>
Untuk tiap kasus, pilih manusia saja, cermin/pelatih, kopilot, atau delegasi terbatas. Jelaskan alasan dan syarat eskalasi.

+ menjadwalkan rapat rutin;
+ meminta maaf kepada sahabat;
+ merangkum masukan warga;
+ menjawab keluhan pelanggan tentang keselamatan;
+ menerjemahkan penjelasan teknis;
+ menyepakati harga di bawah batas tertentu.

=== Perform: Spesifikasi Kopilot Komunikasi
<perform-spesifikasi-kopilot-komunikasi>
Rancang untuk salah satu dari lima domain. Dokumen memuat:

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Unsur], [Isi],),
  table.hline(),
  [Pribadi dan relasi], [],
  [Tujuan dan keadaan TAIDA], [],
  [Peran AI], [cermin/pelatih/penerjemah/kopilot/mediator/agen],
  [Data minimum], [],
  [Sumber pengetahuan], [],
  [Kewenangan yang diberikan], [],
  [Larangan], [],
  [Risiko dan mitigasi], [],
  [Kondisi eskalasi], [],
  [Tinjauan manusia], [],
  [Retensi dan penghapusan data], [],
  [Bukti keberhasilan tugas dan relasi], [],
)
Uji spesifikasi dengan tiga skenario: normal, ambigu, dan berisiko. Catat keluaran yang diterima, diubah, atau ditolak beserta alasannya.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Kriteria], [Mulai berkembang], [Cakap],),
  table.hline(),
  [Proporsionalitas], [AI dipakai karena tersedia], [Peran sesuai risiko dan nilai relasi],
  [Data], [Semua konteks dimasukkan], [Data minimum, persetujuan, dan retensi jelas],
  [Kewenangan], [Kabur], [Batas, larangan, dan eskalasi dapat diuji],
  [Verifikasi], [Persetujuan simbolis], [Peninjau kompeten dapat menolak dan memperbaiki],
  [Tanggung jawab], [Kesalahan dibebankan pada AI], [Pemilik keputusan dan pemulihan jelas],
  [Relasi], [Hanya efisiensi], [Keaslian, martabat, dan kepercayaan dinilai],
)
=== Refleksi
<refleksi-14>
+ Apakah AI mengurangi hambatan atau mengurangi kehadiran manusia yang dibutuhkan?
+ Data pribadi apa yang sebenarnya tidak perlu?
+ Siapa dirugikan jika keluaran salah?
+ Dapatkah orang mengetahui bahwa AI terlibat dan membantah hasilnya?
+ Kompetensi manusia apa yang tetap saya latih?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-15>
AI dapat menjadi cermin, pelatih, penerjemah, kopilot, mediator, atau agen terdelegasi. Semakin sensitif data, tidak dapat dibalik keputusan, besar dampak, dan tinggi nilai relasi, semakin kuat kebutuhan akan keterlibatan manusia. Komunikasi berpusat pada manusia menjaga tujuan, kebenaran, persetujuan, privasi, otonomi, kewenangan, dan akuntabilitas.

#quote(block: true)[
#strong[Gunakan AI untuk memperbesar kemampuan manusia memahami dan melayani---bukan untuk memperkecil martabat, pilihan, dan tanggung jawab manusia.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-13>
Lihat #cite(<floridi2018ai4people>, form: "prose"), #cite(<unesco2021ethics>, form: "prose"), #cite(<nist2023airmf>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

#heading(level: 1, numbering: none)[Bagian IV --- Memiliki Harta Karun Itu]
<bagian-iv-memiliki-harta-karun-itu-1>
== Capstone: Menjadi Komunikator yang Utuh
<capstone-menjadi-komunikator-yang-utuh>
#block[
#callout(
body: 
[
#strong[Kompetensi komunikasi baru menjadi milik kita ketika dapat digunakan dalam situasi yang hidup, berubah, dan tidak sepenuhnya dapat diprediksi---ketika kita perlu mendengarkan, memilih, menyesuaikan, bertindak, dan tetap menjaga relasi.]

]
, 
title: 
[
Esensi Bab
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Target Harta Karun
<target-harta-karun-16>
Harta karun Bagian IV adalah kompetensi yang telah menyatu: kemampuan melihat pribadi, memilih peran, merumuskan tujuan, membaca keadaan TAIDA, menggunakan repertoar serta bahasa yang tepat, membentuk kesepakatan dan tindakan, menilai relasi, serta menggunakan AI dengan batas yang bertanggung jawab.

Anda memperlihatkan bahwa harta karun ini mulai menjadi milik Anda apabila mampu menghadapi satu persoalan nyata yang melibatkan sedikitnya dua pribadi atau beberapa pemangku kepentingan, menghasilkan bukti kinerja, menerima umpan balik, melakukan perbaikan, dan menjelaskan pembelajaran yang terjadi.

=== Tujuan Belajar
<tujuan-belajar-15>
Pada akhir bab ini, Anda mampu:

- mengintegrasikan seluruh kerangka komunikasi interpersonal dan publik;
- merancang komunikasi berdasarkan pribadi, peran, domain, tujuan, keadaan, dan relasi;
- beradaptasi terhadap respons yang tidak diprediksi;
- membedakan tindakan yang berhasil dari tekanan yang menghasilkan kepatuhan semu;
- memilih bagian komunikasi yang layak dibantu AI dan yang harus tetap dilakukan manusia;
- menyusun kesepakatan, tindakan, serta evaluasi relasi;
- menunjukkan perkembangan melalui portofolio berbasis bukti; dan
- menetapkan sasaran pertumbuhan komunikasi berikutnya.

=== Kata Kunci
<kata-kunci-15>
#strong[Capstone], #strong[integrasi kompetensi], #strong[kinerja autentik], #strong[portofolio], #strong[adaptasi], #strong[umpan balik], #strong[refleksi dalam tindakan], #strong[kesepakatan], #strong[tindakan], #strong[relasi], #strong[pertimbangan AI], dan #strong[sasaran pertumbuhan].

=== Persiapan: Kembalilah ke Sasaran Awal
<persiapan-kembalilah-ke-sasaran-awal>
Pada Pendahuluan, Anda diminta membuat peta relasi dan menetapkan satu sasaran pertumbuhan komunikasi. Ambil kembali catatan itu. Jawablah:

+ Situasi apa yang dahulu paling sulit?
+ Kebiasaan komunikasi apa yang ingin Anda ubah?
+ Bukti apa yang sekarang menunjukkan pertumbuhan?
+ Kesulitan apa yang masih berulang?
+ Siapa yang telah membantu Anda belajar?

Jangan menilai perjalanan hanya dari rasa percaya diri. Cari perubahan yang dapat diamati: pertanyaan yang lebih baik, kemampuan menunda reaksi, keberanian menyatakan batas, perbaikan bahasa, kesepakatan yang lebih jelas, atau relasi yang lebih sehat.

=== Attention: Kembali ke Los Angeles
<attention-kembali-ke-los-angeles>
Tujuh tahun setelah malam 13 Desember 1989 ketika saya pertama kali melihat lampu-lampu Los Angeles dari pesawat, masa tugas belajar saya selesai. Dalam perjalanan pulang ke Indonesia, saya mengumpulkan uang dan mengajak Ina, Gladys, Kezia, serta Andria kembali ke kota itu. Kami menghabiskan waktu seminggu menjelajahinya.

Bagi keluarga saya, perjalanan itu mungkin liburan yang mengesankan. Bagi saya, ia menutup sebuah lingkar. Dahulu saya tiba sebagai seorang pemuda yang membawa impian seorang anak Tomohon. Kini saya kembali bersama orang-orang yang telah menjadi bagian penting dari perjalanan hidup saya.

Tujuan geografis memang tercapai. Namun, harta karun yang dibawa pulang bukan sekadar pengalaman berada di luar negeri. Ada pengetahuan, ketekunan, rasa syukur, pertolongan banyak orang, dan keluarga yang membuat pencapaian itu bermakna.

#block[
#callout(
body: 
[
Kita sering mengira harta karun berada di ujung perjalanan. Setelah tiba, kita menyadari bahwa harta itu juga terdapat dalam pribadi yang bertumbuh, relasi yang menemani, keputusan yang kita pertanggungjawabkan, dan kemampuan membagikan pengalaman kepada orang lain.

]
, 
title: 
[
Catatan dari Perjalanan Saya
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#emph[Daya Tarik] mengajak pembaca mengembangkan isi yang bertahan: kisah hidup, konsep yang mencerdaskan, serta opini yang terbuka untuk diuji @langi2025dayatarik. Capstone ini meminta Anda melakukan hal serupa---bukan tampil sempurna, melainkan memperlihatkan pengalaman yang telah diolah menjadi kompetensi dan hikmat.

=== Interest: Bab Ini Bukan Materi Baru
<interest-bab-ini-bukan-materi-baru>
Capstone menyatukan empat belas bab sebelumnya:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Lingkar pembelajaran], [Kompetensi inti],),
  table.hline(),
  [Diri], [memisahkan fakta, cerita, emosi, dan pilihan],
  [Keluarga dan sahabat], [mendengarkan, berempati, menyatakan batas, dan memperbaiki],
  [Rekan kerja dan pelanggan], [menemukan masalah serta menciptakan nilai bersama],
  [TAIDA], [mengenali sasaran dan menggerakkan keadaan secara etis],
  [Negosiasi], [menemukan kepentingan dan kesepakatan yang dapat diterima],
  [Komunitas], [bertindak bersama di tengah perbedaan dan kuasa],
  [Dunia], [menyumbangkan gagasan secara akurat dan bertanggung jawab],
  [AI], [memperbesar kemampuan tanpa menyerahkan relasi dan tanggung jawab],
)
Belajar melalui pengalaman memerlukan gerak antara tindakan konkret, refleksi, pembentukan konsep, dan percobaan berikutnya @kolb1984experiential. Profesional juga perlu mampu berpikir di tengah tindakan, membaca kejutan, dan menyesuaikan praktik @schon1983reflective. Karena itu, capstone tidak dinilai hanya dari rencana. Perubahan ketika rencana bertemu respons merupakan bukti utama.

=== Desire: Kerangka Komunikator yang Utuh
<desire-kerangka-komunikator-yang-utuh>
Sebelum dan selama kinerja, gunakan dua belas pertanyaan.

==== 1. Siapa pribadi yang terlibat?
<siapa-pribadi-yang-terlibat>
Jangan berhenti pada jabatan atau kategori. Apa pengalaman, kebutuhan, nilai, kerentanan, dan kebebasan yang perlu dihormati?

==== 2. Kecenderungan apa yang relevan?
<kecenderungan-apa-yang-relevan>
Gunakan kepribadian sebagai dugaan tentang preferensi komunikasi, bukan label atau takdir. Periksa melalui respons.

==== 3. Peran naratif apa yang dimainkan?
<peran-naratif-apa-yang-dimainkan>
Siapa Anda dalam situasi ini---sahabat, ahli, pemimpin, pelanggan, warga, fasilitator, atau pembicara publik? Peran apa yang dijalankan pihak lain? Apakah Anda membawa peran yang tepat?

==== 4. Dalam domain apa komunikasi berlangsung?
<dalam-domain-apa-komunikasi-berlangsung>
Apakah persoalan berada dalam diri, relasi dekat, pekerjaan, komunitas, atau publik? Satu peristiwa dapat melintasi domain dan memerlukan batas berbeda.

==== 5. Apa tujuan yang bertanggung jawab?
<apa-tujuan-yang-bertanggung-jawab>
Nyatakan perubahan yang diharapkan pada pemahaman, kesepakatan, tindakan, dan relasi. Tujuan tidak boleh menghapus pilihan pihak lain.

==== 6. Di mana keadaan awal TAIDA?
<di-mana-keadaan-awal-taida>
Apakah pihak belum menyadari persoalan, sudah memperhatikan, berminat, menginginkan hasil, atau siap bertindak? Jangan mendorong langkah berikutnya hanya karena Anda telah menyiapkan materi.

==== 7. Repertoar dan bahasa apa yang sesuai?
<repertoar-dan-bahasa-apa-yang-sesuai>
Pilih mendengarkan, pertanyaan, kisah, fakta, konsep, opini, analogi, data, visual, demonstrasi, negosiasi, atau keheningan. Pertahankan makna inti sambil menyesuaikan bahasa.

==== 8. Bagaimana respons dibaca?
<bagaimana-respons-dibaca>
Dengarkan kata, makna, emosi, pertanyaan, penolakan, dan keheningan. Isyarat nonverbal adalah petunjuk yang perlu diperiksa, bukan bukti pikiran.

==== 9. Bagian apa yang boleh dibantu AI?
<bagian-apa-yang-boleh-dibantu-ai>
Tentukan peran AI, data minimum, batas kewenangan, risiko, dan tinjauan. Komunikasi pembawa relasi tetap memerlukan kepemilikan manusia.

==== 10. Kesepakatan apa yang dapat diterima?
<kesepakatan-apa-yang-dapat-diterima>
Bedakan posisi dan kepentingan. Hasil dapat berupa kesepakatan penuh, sebagian, uji coba, penundaan dengan syarat, atau "tidak" yang jelas.

==== 11. Tindakan apa yang dilakukan?
<tindakan-apa-yang-dilakukan>
Nyatakan siapa melakukan apa, kapan, dengan sumber daya apa, ukuran selesai, dan waktu tinjauan.

==== 12. Bagaimana keadaan relasi sesudahnya?
<bagaimana-keadaan-relasi-sesudahnya>
Apakah kepercayaan, rasa aman, kejelasan, dan kemampuan bekerja kembali meningkat, tetap, atau menurun? Apa yang perlu diperbaiki?

Rangkuman kerangka:

#quote(block: true)[
#strong[Pribadi → Kepribadian → Peran → Tujuan → Repertoar → Bahasa → Respons → Kesepakatan → Tindakan → Relasi]
]

yang bergerak melalui:

#quote(block: true)[
#strong[Sasaran → Perhatian → Minat → Keinginan → Tindakan]
]

=== Karakter Komunikator
<karakter-komunikator>
Kompetensi tidak hanya berupa teknik. Ia terlihat dalam karakter komunikasi:

- #strong[rasa ingin tahu:] bertanya karena belum tahu;
- #strong[kejelasan:] menyatakan makna, batas, dan komitmen;
- #strong[kerendahan hati:] bersedia dikoreksi dan mengubah pendapat;
- #strong[keberanian:] menghadapi percakapan sulit tanpa menyerang;
- #strong[kepedulian:] memperhitungkan pengalaman serta dampak pada orang lain;
- #strong[akuntabilitas:] memiliki kata, tindakan, kesalahan, dan perbaikan.

Keaslian bukan memakai gaya yang sama kepada semua orang. Keaslian ialah keselarasan antara nilai, peran, tujuan, bahasa, dan tindakan.

=== Standar Akhir Komunikasi yang Baik
<standar-akhir-komunikasi-yang-baik>
Tindakan saja tidak cukup. Manipulasi dapat menghasilkan tindakan sambil merusak otonomi dan kepercayaan. Relasi saja juga tidak cukup. Kehangatan tanpa kejelasan dapat membiarkan masalah berlarut-larut.

Gunakan standar:

#quote(block: true)[
#strong[Komunikasi yang baik = tindakan yang bernilai + relasi yang sehat + tanggung jawab yang terpelihara.]
]

Tidak semua kasus harus berakhir dengan persetujuan. "Tidak" yang jujur dapat lebih baik daripada "ya" yang dipaksakan atau tidak dilaksanakan.

=== Praktis: Merancang Capstone
<praktis-merancang-capstone>
Pilih satu domain:

+ #strong[Diri dan interpersonal:] mengambil keputusan lalu menyampaikannya kepada orang terkait.
+ #strong[Keluarga/sahabat:] memperbaiki relasi atau menetapkan batas yang sehat.
+ #strong[Pekerjaan/pelanggan:] menemukan masalah, menawarkan nilai, dan membuat kesepakatan.
+ #strong[Komunitas:] memfasilitasi deliberasi serta tindakan kolektif.
+ #strong[Publik:] menyampaikan gagasan dan mengelola respons secara bertanggung jawab.

Pilih persoalan yang autentik tetapi aman. Hindari mengungkap data rahasia atau memaksa pihak lain berpartisipasi demi nilai. Jika menggunakan simulasi, buat informasi tersembunyi agar respons tidak sepenuhnya dapat ditebak.

==== Rencana Satu Halaman
<rencana-satu-halaman>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Unsur], [Isi],),
  table.hline(),
  [Pribadi dan peran], [],
  [Domain dan riwayat relasi], [],
  [Tujuan tugas dan relasi], [],
  [Keadaan TAIDA awal], [],
  [Fakta dan asumsi], [],
  [Repertoar dan bahasa], [],
  [Kemungkinan respons], [],
  [Peran serta batas AI], [],
  [Kesepakatan/tindakan yang mungkin], [],
  [Risiko etik dan mitigasi], [],
)
Jangan menulis naskah lengkap. Siapkan tujuan, bukti, pertanyaan, dan pilihan. Naskah yang terlalu kaku mengurangi kemampuan mendengarkan.

=== Perform: Kinerja Komunikasi Terpadu
<perform-kinerja-komunikasi-terpadu>
Kinerja berlangsung 8--12 menit dalam empat fase:

+ #strong[Membuka dan mengenali:] meminta izin, membangun relevansi, dan mengenali pribadi.
+ #strong[Mendengarkan dan menemukan:] menguji fakta, kebutuhan, kepentingan, serta keadaan.
+ #strong[Mengomunikasikan dan menegosiasikan:] memilih repertoar, menyesuaikan bahasa, serta mengembangkan pilihan.
+ #strong[Menyepakati langkah berikutnya:] mengonfirmasi tindakan atau menutup tanpa kesepakatan secara sehat.

Mitra memperoleh informasi tersembunyi yang hanya dibagikan jika komunikator bertanya atau menciptakan rasa aman. Pengamat mencatat bukti, bukan menebak niat.

==== Putaran Perbaikan
<putaran-perbaikan>
Setelah putaran pertama:

- pihak lain menjelaskan dampak yang dialami;
- pengamat memberikan dua bukti kekuatan dan satu prioritas perbaikan;
- komunikator menjelaskan pembelajaran, bukan membela niat;
- adegan penting diulang selama 2--3 menit.

Perbandingan versi pertama dan kedua merupakan bukti belajar.

=== Contoh Skenario
<contoh-skenario>
==== Proyek Terlambat
<proyek-terlambat>
Anda memimpin tim. Seorang anggota belum menyerahkan bagian penting. Informasi tersembunyi: ia sedang merawat anggota keluarga dan takut dianggap tidak profesional. Tujuan bukan hanya memperoleh berkas, tetapi memahami keadaan, membagi ulang pekerjaan secara adil, dan menjaga martabat.

==== Konflik Komunitas
<konflik-komunitas>
Warga menolak kegiatan malam mahasiswa. Informasi tersembunyi: ada pengalaman kecelakaan sebelumnya yang tidak pernah ditindaklanjuti. Tujuan ialah membingkai masalah bersama, mendengar dampak, dan merancang uji coba dengan perlindungan.

==== Pesan Publik tentang AI
<pesan-publik-tentang-ai>
Anda menjelaskan penggunaan AI dalam tugas mahasiswa. Audiens mencakup mahasiswa, dosen, dan publik. Tujuan ialah membedakan bantuan belajar dari penggantian proses belajar, menyatakan bukti serta batas, dan mengundang satu tindakan bertanggung jawab.

==== Perbaikan Relasi
<perbaikan-relasi>
Anda menghubungi sahabat setelah konflik. Tujuan bukan memaksa kedekatan kembali, melainkan mengakui dampak, mendengar, menyatakan batas, dan menawarkan langkah perbaikan yang dapat ditolak.

=== Pertimbangan AI dalam Capstone
<pertimbangan-ai-dalam-capstone>
Kedalaman otomatisasi bukan ukuran nilai tinggi. Nilai tinggi terlihat dari pertimbangan yang tepat.

- #strong[Persiapan:] AI membantu pertanyaan, simulasi, terjemahan, atau kritik.
- #strong[Kopilot:] AI membantu pencatatan atau ringkasan dengan persetujuan.
- #strong[Delegasi:] hanya untuk tugas beraturan, dapat dibalik, berwenang jelas, dan bernilai relasi rendah.

Dokumentasikan keluaran yang diterima, diubah, dan ditolak. Jelaskan mengapa tidak menggunakan lebih banyak AI. Kemampuan menetapkan batas merupakan kompetensi.

=== Portofolio Akhir
<portofolio-akhir>
Portofolio bukan kumpulan esai, melainkan jejak kinerja:

+ peta pribadi dan peran;
+ tujuan serta keadaan awal;
+ rencana komunikasi;
+ rekaman, artefak, atau lembar observasi;
+ respons yang tidak diprediksi;
+ penyesuaian yang dilakukan;
+ kesepakatan dan tindakan;
+ evaluasi keadaan relasi;
+ kritik penggunaan AI;
+ versi pertama, umpan balik, dan versi perbaikan;
+ refleksi 600--900 kata; serta
+ sasaran pertumbuhan berikutnya.

Lindungi identitas. Gunakan nama samaran, hapus data sensitif, dan peroleh izin untuk rekaman. Jangan mengunggah percakapan pribadi ke layanan AI tanpa persetujuan.

=== Rubrik Universal Capstone
<rubrik-universal-capstone>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Kriteria], [Awal], [Berkembang], [Cakap], [Unggul],),
  table.hline(),
  [Pribadi dan peran], [Berbasis kategori], [Peran dikenali], [Pribadi, peran, dan konteks dipetakan], [Pemetaan direvisi dari respons],
  [Tujuan dan keadaan], [Tujuan kabur], [Salah satu terlihat], [Tujuan tugas/relasi dan TAIDA jelas], [Tujuan disesuaikan secara bertanggung jawab],
  [Repertoar, bahasa, AI], [Satu cara/otomatis], [Ada variasi], [Relevan, autentik, dan berbatas], [Pilihan dijelaskan dengan pertimbangan etik],
  [Mendengar dan adaptasi], [Naskah dipaksakan], [Respons dicatat], [Makna diparafrasakan dan pendekatan berubah], [Kejutan menjadi pembelajaran bersama],
  [Kesepakatan dan tindakan], [Persetujuan diasumsikan], [Langkah masih kabur], [Pelaku, tindakan, waktu, dan bukti jelas], [Kelayakan, kuasa, risiko, dan tinjauan terkelola],
  [Relasi dan refleksi], [Dampak diabaikan], [Refleksi berupa kesan], [Bukti dampak dan perbaikan jelas], [Pola diri, batas, dan transfer pembelajaran terlihat],
)
Nilai mengukur perilaku yang dapat dipelajari, bukan nilai seseorang sebagai manusia. Kesalahan yang dikenali dan diperbaiki dapat menunjukkan kompetensi lebih tinggi daripada penampilan lancar tanpa refleksi.

=== Refleksi Akhir
<refleksi-akhir>
Tuliskan jawaban secara spesifik:

+ Sebelum mempelajari buku ini, apa respons otomatis saya?
+ Repertoar baru apa yang sekarang dapat saya gunakan?
+ Karakter komunikator apa yang paling kuat dalam diri saya?
+ Karakter apa yang perlu ditumbuhkan?
+ Apa aturan pribadi saya dalam menggunakan AI?
+ Bukti apa yang menunjukkan komunikasi saya lebih efektif?
+ Siapa yang mengalami dampak pertumbuhan saya?
+ Dalam 90 hari berikutnya, kebiasaan apa yang akan saya latih, seberapa sering, dan dari siapa saya meminta umpan balik?

=== Ringkasan Satu Menit
<ringkasan-satu-menit-16>
Komunikator yang utuh melihat pribadi sebelum pesan; memandang kepribadian sebagai kecenderungan; memilih peran, tujuan, repertoar, dan bahasa; membaca respons; bergerak melalui TAIDA; merundingkan kesepakatan; mengoordinasikan tindakan; menjaga relasi; serta menempatkan AI di bawah kewenangan dan tanggung jawab manusia. Kompetensi dibuktikan melalui kinerja, umpan balik, perbaikan, dan refleksi.

#quote(block: true)[
#strong[Harta karun komunikasi bukan kemampuan mengendalikan orang lain. Harta itu adalah kemampuan hadir sebagai manusia yang ingin memahami, berani menyatakan kebenaran, mampu menciptakan nilai, bersedia bertanggung jawab, dan selalu menyisakan ruang untuk berelasi kembali.]
]

=== Rujukan dan Bacaan Lanjutan
<rujukan-dan-bacaan-lanjutan-14>
Lihat #cite(<kolb1984experiential>, form: "prose"), #cite(<schon1983reflective>, form: "prose"), #cite(<rogers1961becoming>, form: "prose"), #cite(<fisher2011getting>, form: "prose"), #cite(<nist2023airmf>, form: "prose"), dan #cite(<langi2025dayatarik>, form: "prose").

#heading(level: 2, numbering: none)[Lampiran]
<lampiran>
== Panduan Mengerjakan Tugas
<panduan-mengerjakan-tugas>
Lampiran ini membantu Anda mengubah pengalaman komunikasi menjadi proses belajar yang tertib, etis, dan dapat dinilai. Tujuannya bukan membuat setiap percakapan terasa seperti proyek penelitian, melainkan menolong Anda hadir dengan persiapan yang baik, bertindak dengan sadar, dan belajar dari bukti.

=== Memilih Kasus yang Layak
<memilih-kasus-yang-layak>
Pilih kasus yang nyata, cukup penting untuk dipelajari, tetapi tetap aman bagi semua pihak. Kasus yang baik memiliki sasaran yang jelas, melibatkan respons orang lain, memberi ruang untuk memilih strategi, dan memungkinkan Anda melakukan refleksi sesudahnya.

Gunakan lima pertanyaan penyaring berikut.

+ #strong[Relevan:] apakah kasus ini berhubungan dengan kompetensi bab?
+ #strong[Autentik:] apakah ada kebutuhan, perbedaan, atau tindakan nyata yang perlu ditangani?
+ #strong[Terjangkau:] dapatkah tugas diselesaikan dengan waktu dan sumber daya yang tersedia?
+ #strong[Aman:] apakah risiko emosional, sosial, akademik, dan profesional dapat dikelola?
+ #strong[Etis:] dapatkah partisipasi berlangsung secara sukarela, dengan privasi dan martabat terjaga?

Jangan memilih kasus yang mengharuskan Anda membuka rahasia organisasi, merekam orang tanpa izin, mendorong seseorang membicarakan trauma, atau mengambil peran profesional yang tidak Anda miliki. Jika kasus nyata terlalu sensitif, gunakan simulasi atau kasus komposit yang telah disamarkan.

=== Persetujuan dan Privasi
<persetujuan-dan-privasi>
Sebelum melibatkan orang lain, jelaskan tujuan tugas, bentuk partisipasi, jenis bukti yang dikumpulkan, siapa yang akan melihatnya, dan hak mereka untuk menolak atau berhenti. Persetujuan bukan sekadar kalimat formal; persetujuan harus diberikan tanpa tekanan.

Contoh permintaan persetujuan:

#quote(block: true)[
Saya sedang mengerjakan tugas pembelajaran komunikasi. Apakah Anda bersedia melakukan percakapan sekitar 15 menit? Dengan izin Anda, saya akan membuat catatan untuk dianalisis oleh saya dan dosen. Nama serta rincian pengenal akan saya samarkan. Anda boleh tidak menjawab pertanyaan tertentu atau menghentikan percakapan kapan saja.
]

Jika rekaman diperlukan, mintalah izin khusus untuk merekam. Izin berbicara tidak otomatis berarti izin merekam, mengunggah, atau membagikan. Simpan hanya data yang benar-benar diperlukan dan hapus sesuai jadwal yang telah disampaikan.

==== Panduan Penyamaran Identitas
<panduan-penyamaran-identitas>
- Ganti nama dengan kode, misalnya #strong[Mitra A] atau #strong[Warga 2].
- Hilangkan alamat, nomor identitas, nomor kontak, dan rincian unik.
- Ubah detail periferal yang tidak memengaruhi analisis.
- Pisahkan daftar identitas asli dari berkas tugas, jika daftar itu memang harus ada.
- Jangan memasukkan data pribadi atau rahasia ke layanan AI tanpa dasar izin dan perlindungan yang memadai.

=== Siklus Pengerjaan
<siklus-pengerjaan>
Gunakan alur #strong[Plan → Perform → Evidence → Reflect → Improve].

==== 1. Plan --- Merencanakan
<plan-merencanakan>
Tuliskan secara ringkas:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Unsur], [Pertanyaan pemandu],),
  table.hline(),
  [Sasaran], [Perubahan apa yang ingin dicapai pada pemahaman, tindakan, dan relasi?],
  [Pribadi dan peran], [Siapa yang terlibat dan peran apa yang sedang dijalankan?],
  [Keadaan awal], [Di tahap TAIDA mana pihak lain berada? Apa buktinya?],
  [Fakta dan asumsi], [Apa yang diketahui? Apa yang masih perlu diperiksa?],
  [Repertoar], [Apakah Anda perlu bertanya, mendengarkan, menjelaskan, bercerita, memvisualkan, atau bernegosiasi?],
  [Risiko], [Apa yang dapat merugikan privasi, otonomi, martabat, atau relasi?],
  [Batas AI], [Bagian apa yang boleh dibantu AI dan apa yang harus Anda miliki sendiri?],
)
Rencana adalah peta, bukan naskah kaku. Sisakan ruang untuk mendengarkan dan berubah.

==== 2. Perform --- Melakukan
<perform-melakukan>
Laksanakan komunikasi dengan hadir penuh. Mulailah dengan izin dan konteks, dengarkan respons, periksa pemahaman, lalu sesuaikan pilihan bahasa maupun tindakan. Jika situasi berubah menjadi tidak aman atau melampaui kompetensi Anda, hentikan dengan hormat dan minta bantuan yang tepat.

==== 3. Evidence --- Mengumpulkan Bukti
<evidence-mengumpulkan-bukti>
Bukti yang memadai dapat berupa:

- catatan observasi dengan waktu dan konteks;
- kutipan singkat yang telah disamarkan;
- transkrip bagian penting, bukan seluruh percakapan;
- artefak pesan versi awal dan versi perbaikan;
- formulir umpan balik mitra atau pengamat;
- butir kesepakatan dan tindak lanjut;
- rekaman yang dibuat dengan persetujuan; atau
- catatan penggunaan AI yang menyebut tujuan, data, keluaran, dan verifikasi.

Bukti yang lemah biasanya hanya berupa klaim, seperti "percakapan berjalan baik", tanpa perilaku atau respons yang dapat diamati. Bukti yang lebih kuat berbunyi, misalnya: "Setelah saya merangkum kekhawatirannya dan bertanya apakah rangkuman itu tepat, Mitra A mengoreksi satu asumsi lalu mengusulkan jadwal baru."

==== 4. Reflect --- Merefleksikan
<reflect-merefleksikan>
Pisahkan niat dari dampak. Jawablah:

+ Apa yang sungguh terjadi?
+ Respons apa yang tidak saya perkirakan?
+ Pilihan saya mana yang membantu atau menghambat?
+ Apa dampaknya pada tindakan dan keadaan relasi?
+ Asumsi apa yang dikoreksi?
+ Apa yang tetap belum saya ketahui?

Refleksi bukan pembelaan diri. Ia adalah keberanian menatap pengalaman secara jujur agar pengalaman dapat menjadi pengetahuan @schon1983reflective.

==== 5. Improve --- Memperbaiki
<improve-memperbaiki>
Pilih satu atau dua perubahan yang spesifik. Ulangi bagian penting, revisi artefak, atau lakukan tindak lanjut jika pihak lain menyetujuinya. Tunjukkan perbedaan antara versi awal dan versi perbaikan serta alasan perubahan itu.

=== Format Laporan Ringkas
<format-laporan-ringkas>
Gunakan susunan berikut jika tugas tidak menentukan format lain.

+ #strong[Konteks dan persetujuan] --- 100--150 kata.
+ #strong[Rencana] --- sasaran, keadaan awal, repertoar, risiko, dan batas AI.
+ #strong[Kinerja] --- deskripsi ringkas urutan komunikasi.
+ #strong[Bukti] --- dua sampai empat bukti utama.
+ #strong[Refleksi] --- analisis dampak pada tindakan dan relasi.
+ #strong[Perbaikan] --- perubahan yang dilakukan atau akan diuji.
+ #strong[Pernyataan etika dan AI] --- data yang digunakan, persetujuan, peran AI, verifikasi, dan tanggung jawab akhir.

=== Daftar Periksa Pengumpulan
<daftar-periksa-pengumpulan>
- ☐ Kasus sesuai dengan tujuan belajar dan aman untuk dikerjakan.
- ☐ Persetujuan diperoleh dan dapat ditarik kembali.
- ☐ Identitas serta data sensitif telah dilindungi.
- ☐ Sasaran, peran, keadaan TAIDA, dan ukuran keberhasilan dinyatakan.
- ☐ Bukti menunjukkan perilaku atau respons, bukan hanya kesan.
- ☐ Niat dibedakan dari dampak.
- ☐ Ada umpan balik dan perbaikan yang terlihat.
- ☐ Penggunaan AI diungkapkan secara proporsional.
- ☐ Fakta, kutipan, dan rujukan telah diperiksa.
- ☐ Anda bersedia bertanggung jawab atas isi dan tindak lanjutnya.

Tugas yang kuat tidak selalu menceritakan keberhasilan yang mulus. Kadang-kadang bukti belajar terbaik muncul ketika Anda dapat menunjukkan kesalahan, mendengarkan dampaknya, lalu mencoba kembali dengan lebih bijaksana.

== Portofolio Komunikasi
<portofolio-komunikasi>
Portofolio adalah kisah perkembangan yang ditopang bukti. Ia tidak hanya memamerkan hasil terbaik, tetapi memperlihatkan bagaimana Anda merencanakan, bertindak, menerima respons, memperbaiki diri, dan menjaga tanggung jawab.

=== Struktur Portofolio
<struktur-portofolio>
Susun portofolio dalam lima bagian:

+ #strong[Profil awal:] sasaran pertumbuhan dan peta karakter komunikasi.
+ #strong[Artefak inti:] hasil tugas dari lingkar diri, relasi, profesional, komunitas, publik, dan AI.
+ #strong[Jejak perbaikan:] versi awal, umpan balik, dan versi berikutnya.
+ #strong[Capstone:] rancangan, bukti kinerja, refleksi, dan tindak lanjut.
+ #strong[Refleksi akhir:] perubahan yang terlihat dan sasaran belajar selanjutnya.

Untuk setiap artefak, sertakan konteks, tanggal, kompetensi, bukti, umpan balik, perbaikan, dan catatan etika. Gunakan nama berkas yang konsisten, misalnya #NormalTok("M07-pitch-taida-versi-2.pdf");. Simpan data identitas terpisah dari artefak akademik.

=== Template Peta Karakter Komunikasi Pribadi
<template-peta-karakter-komunikasi-pribadi>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Unsur], [Catatan Anda],),
  table.hline(),
  [Nilai yang ingin tampak dalam komunikasi], [],
  [Kekuatan yang telah terlihat dalam bukti], [],
  [Pola yang sering menghambat], [],
  [Situasi yang memicu respons otomatis], [],
  [Peran yang nyaman saya jalankan], [],
  [Peran yang perlu saya latih], [],
  [Repertoar yang sudah kuat], [],
  [Repertoar yang perlu dikembangkan], [],
  [Satu sasaran perilaku terukur], [],
  [Orang yang dapat memberi umpan balik jujur], [],
)
Kepribadian dalam peta ini adalah hipotesis kerja, bukan stempel. Perbarui berdasarkan perilaku dan umpan balik, bukan hanya berdasarkan tes atau kesan diri.

=== Template Jurnal Komunikasi dengan Diri Sendiri
<template-jurnal-komunikasi-dengan-diri-sendiri>
#strong[Peristiwa:] \ #strong[Fakta yang dapat diamati:] \ #strong[Cerita atau tafsiran yang muncul:] \ #strong[Emosi dan kebutuhan:] \ #strong[Respons otomatis yang ingin saya lakukan:] \ #strong[Pilihan respons lain:] \ #strong[Nilai yang ingin saya hidupi:] \ #strong[Tindakan kecil berikutnya:] \ #strong[Pelajaran setelah tindakan:]

=== Template Episode Relasi
<template-episode-relasi>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Tahap], [Isi],),
  table.hline(),
  [Konteks dan riwayat relasi], [],
  [Persetujuan dan batas privasi], [],
  [Tujuan percakapan], [],
  [Kebutuhan/kepentingan saya], [],
  [Kebutuhan/kepentingan pihak lain yang perlu diperiksa], [],
  [Pembukaan yang digunakan], [],
  [Pertanyaan dan rangkuman penting], [],
  [Respons yang saya amati], [],
  [Kesepakatan atau batas], [],
  [Keadaan relasi sesudahnya], [],
  [Perbaikan yang akan dicoba], [],
)
=== Template Pitch TAIDA
<template-pitch-taida>
==== Target
<target>
- Siapa pribadi atau kelompok yang ingin dilayani?
- Masalah, pekerjaan, atau aspirasi apa yang relevan?
- Apa bukti tentang keadaan awal mereka?

==== Attention
<attention>
- Pembuka apa yang relevan tanpa menakut-nakuti atau mengeksploitasi?
- Dalam 20 detik pertama, mengapa mereka perlu memberi perhatian?

==== Interest
<interest>
- Pertanyaan apa yang menolong mereka menghubungkan pesan dengan pengalaman?
- Fakta, kisah, konsep, atau demonstrasi apa yang membangun pemahaman?

==== Desire
<desire>
- Nilai apa yang dapat diciptakan?
- Apa manfaat, pengorbanan, risiko, dan alternatifnya?
- Apa yang perlu diverifikasi sebelum membuat klaim?

==== Action
<action>
- Langkah berikutnya apa yang kecil, jelas, dan sukarela?
- Siapa melakukan apa, kapan, dan bagaimana keberhasilannya diperiksa?

#strong[Bukti respons dan adaptasi:] \ #strong[Catatan etika:] \ #strong[Versi perbaikan:]

=== Template Kesepakatan
<template-kesepakatan>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Unsur kesepakatan], [Rumusan],),
  table.hline(),
  [Tujuan bersama], [],
  [Lingkup dan batas], [],
  [Tanggung jawab pihak A], [],
  [Tanggung jawab pihak B], [],
  [Sumber daya/dukungan], [],
  [Tenggat dan tonggak], [],
  [Ukuran selesai], [],
  [Cara memberi kabar bila ada hambatan], [],
  [Waktu peninjauan], [],
  [Cara mengubah atau mengakhiri kesepakatan], [],
)
Kesepakatan yang baik tidak menyembunyikan ketidakpastian. Ia menyediakan cara untuk belajar dan menyesuaikan diri ketika keadaan berubah.

=== Template Refleksi Negosiasi dan Komunitas
<template-refleksi-negosiasi-dan-komunitas>
+ Siapa saja pemangku kepentingan yang hadir, tidak hadir, atau kurang terdengar?
+ Posisi apa yang dinyatakan dan kepentingan apa yang berada di baliknya?
+ Bagaimana perbedaan kuasa memengaruhi partisipasi?
+ Fakta apa yang disepakati dan diperdebatkan?
+ Pilihan apa yang dikembangkan bersama?
+ Siapa memperoleh manfaat dan siapa menanggung risiko?
+ Apakah keputusan benar-benar dapat diterima atau hanya menghasilkan kepatuhan?
+ Bagaimana relasi dan kemampuan bekerja bersama berubah?
+ Mekanisme tinjauan serta pemulihan apa yang diperlukan?

=== Template Dokumentasi Penggunaan AI
<template-dokumentasi-penggunaan-ai>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Unsur], [Catatan],),
  table.hline(),
  [Tanggal dan alat/model], [],
  [Tujuan penggunaan], [],
  [Peran AI: cermin, pelatih, penerjemah, kopilot, mediator, atau delegasi], [],
  [Data yang dimasukkan dan dasar izinnya], [],
  [Instruksi inti yang diberikan], [],
  [Keluaran yang dipakai/tidak dipakai], [],
  [Fakta, bias, dan risiko yang diperiksa], [],
  [Perubahan manusia setelah tinjauan], [],
  [Cara penggunaan diungkapkan], [],
  [Pemilik keputusan dan tanggung jawab akhir], [],
)
Jangan menyalin percakapan sensitif secara utuh ke dalam portofolio. Dokumentasikan secukupnya agar proses dapat dipahami tanpa mengorbankan privasi.

=== Daftar Periksa Portofolio Akhir
<daftar-periksa-portofolio-akhir>
- ☐ Halaman pembuka menjelaskan sasaran pertumbuhan pribadi.
- ☐ Artefak mewakili lebih dari satu domain komunikasi.
- ☐ Setiap artefak memiliki konteks, bukti, dan refleksi.
- ☐ Sedikitnya tiga artefak memperlihatkan versi sebelum dan sesudah umpan balik.
- ☐ Ada contoh ketika respons pihak lain mengubah rencana.
- ☐ Ada bukti kesepakatan atau penutupan yang jelas.
- ☐ Dampak pada relasi dinilai bersama hasil tindakan.
- ☐ Data pribadi telah disamarkan dan izin terdokumentasi.
- ☐ Penggunaan AI dicatat secara jujur dan proporsional.
- ☐ Capstone menunjukkan integrasi kompetensi.
- ☐ Refleksi akhir menyebut bukti pertumbuhan serta sasaran berikutnya.

Portofolio terbaik terasa hidup karena pembacanya dapat mengikuti perjalanan Anda: bukan perjalanan menuju kesempurnaan, melainkan menuju perhatian, kejernihan, keberanian, dan tanggung jawab yang lebih besar.

== Rubrik Kinerja Universal
<rubrik-kinerja-universal>
Rubrik ini digunakan secara konsisten untuk tugas praktik, portofolio, dan capstone. Kelima dimensi memiliki bobot yang sama, masing-masing #strong[20%]. Dosen dapat menyesuaikan bukti yang diminta, tetapi tidak mengubah prinsip dasarnya: komunikasi dinilai dari tindakan, relasi, dan tanggung jawab.

=== Tingkat Kinerja
<tingkat-kinerja>
#table(
  columns: (30%, 40%, 30%),
  align: (auto,right,auto,),
  table.header([Tingkat], [Skor acuan], [Makna umum],),
  table.hline(),
  [#strong[Unggul]], [4], [Pilihan terarah, adaptif, berbasis bukti, dan bertanggung jawab; dampak dapat dijelaskan.],
  [#strong[Cakap]], [3], [Kompetensi utama tampak konsisten, meskipun kedalaman atau adaptasi masih dapat diperkuat.],
  [#strong[Berkembang]], [2], [Sebagian kompetensi tampak, tetapi masih mekanis, tidak lengkap, atau kurang ditopang bukti.],
  [#strong[Awal]], [1], [Kompetensi belum tampak memadai; keputusan bertumpu pada asumsi atau mengabaikan dampak penting.],
)
=== Rubrik Analitik
<rubrik-analitik>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Dimensi], [Unggul --- 4], [Cakap --- 3], [Berkembang --- 2], [Awal --- 1],),
  table.hline(),
  [#strong[\1. Pengenalan pribadi dan karakter]], [Mengakui keunikan, pengalaman, nilai, peran, kebebasan, dan kerentanan pihak; hipotesis tentang karakter diperiksa melalui dialog dan direvisi.], [Mengenali pribadi dan peran secara relevan; menghindari stereotip; beberapa asumsi diperiksa.], [Menggunakan informasi umum atau label; pengenalan pribadi terbatas dan jarang diperiksa.], [Mereduksi pihak menjadi kategori, target, atau alat; stereotip dan asumsi dibiarkan menentukan tindakan.],
  [#strong[\2. Kejelasan tujuan dan pembacaan keadaan]], [Tujuan pada pemahaman, tindakan, dan relasi jelas serta etis; keadaan TAIDA dan konteks dibaca dari bukti; tujuan disesuaikan saat keadaan berubah.], [Tujuan jelas dan keadaan awal cukup terbaca; penyesuaian dilakukan ketika ada respons nyata.], [Tujuan terlalu umum atau berpusat pada diri; pembacaan keadaan lebih banyak berdasarkan dugaan; adaptasi terbatas.], [Tujuan tidak jelas, manipulatif, atau mengabaikan pilihan pihak lain; keadaan tidak dibaca.],
  [#strong[\3. Ketepatan repertoar, bahasa, dan penggunaan AI]], [Memilih serta memadukan mendengarkan, pertanyaan, kisah, fakta, konsep, visual, atau negosiasi secara tepat; bahasa mudah dipahami; AI dipakai dengan batas, verifikasi, dan transparansi.], [Repertoar dan bahasa sesuai; beberapa variasi digunakan; penggunaan AI cukup aman dan ditinjau manusia.], [Repertoar sempit atau bahasa kurang sesuai; penggunaan AI mekanis, kurang diverifikasi, atau kurang diungkapkan.], [Strategi dan bahasa tidak sesuai atau menyesatkan; AI menggantikan kepemilikan manusia, menggunakan data tanpa dasar, atau tidak diperiksa.],
  [#strong[\4. Mendengarkan respons dan beradaptasi]], [Menangkap isi, emosi, kepentingan, keheningan, dan koreksi; memeriksa pemahaman; mengubah rencana secara tepat dan menjelaskan alasannya.], [Mendengarkan dan merangkum dengan cukup akurat; menanggapi pertanyaan/keberatan dan melakukan penyesuaian.], [Respons didengar sebagian, tetapi pembicara segera kembali pada rencana; rangkuman atau adaptasi masih dangkal.], [Mengabaikan, memotong, atau menafsirkan respons tanpa pemeriksaan; tetap memaksakan naskah.],
  [#strong[\5. Kesepakatan, tindakan, relasi, dan etika]], [Hasil jelas, sukarela, realistis, dapat ditinjau, dan bertanggung jawab; privasi, keadilan, serta relasi dijaga; kegagalan atau "tidak" ditutup secara sehat.], [Langkah berikutnya dan tanggung jawab cukup jelas; etika serta keadaan relasi diperhatikan.], [Ada hasil, tetapi tanggung jawab, ukuran, tindak lanjut, atau dampak relasional belum jelas.], [Mengklaim keberhasilan tanpa kesepakatan nyata; menekan kepatuhan; mengabaikan risiko, privasi, atau kerusakan relasi.],
)
=== Menghitung Nilai
<menghitung-nilai>
Gunakan rumus:

#quote(block: true)[
#strong[Nilai akhir = (jumlah skor lima dimensi ÷ 20) × 100]
]

Contoh: skor 3 + 3 + 4 + 2 + 3 = 15. Nilai akhirnya adalah #NormalTok("(15 ÷ 20) × 100 = 75");.

Angka tidak boleh berdiri sendiri. Setiap penilaian perlu disertai bukti perilaku dan satu prioritas perbaikan. Pada tugas berulang, kemajuan antarputaran merupakan informasi yang sama pentingnya dengan skor akhir.

=== Lembar Umpan Balik
<lembar-umpan-balik>
#strong[Nama/identitas samaran komunikator:] \ #strong[Tugas dan konteks:] \ #strong[Tanggal:]

#table(
  columns: 4,
  align: (auto,right,auto,auto,),
  table.header([Dimensi], [Skor 1--4], [Bukti yang diamati], [Langkah perbaikan],),
  table.hline(),
  [Pribadi dan karakter], [], [], [],
  [Tujuan dan keadaan], [], [], [],
  [Repertoar, bahasa, dan AI], [], [], [],
  [Respons dan adaptasi], [], [], [],
  [Kesepakatan, tindakan, relasi, dan etika], [], [], [],
)
#strong[Dua kekuatan berbasis bukti:] \ 1. \ 2.

#strong[Satu prioritas pada percobaan berikutnya:]

#strong[Tanggapan komunikator:] Apa yang saya pahami dari umpan balik ini, dan bagian apa yang akan saya ulang?

=== Prinsip Penggunaan yang Adil
<prinsip-penggunaan-yang-adil>
- Nilailah perilaku yang dapat diamati, bukan dugaan tentang kepribadian atau niat.
- Pertimbangkan konteks, aksesibilitas, bahasa, dan kebutuhan akomodasi.
- Jangan menyamakan gaya ekstrovert dengan kompetensi komunikasi.
- Pisahkan kualitas hasil dari kemewahan teknologi atau produksi media.
- Beri ruang bagi "tidak ada kesepakatan" apabila penutupan berlangsung jelas, etis, dan relasional.
- Jangan menghukum pengungkapan penggunaan AI; nilailah ketepatan, transparansi, verifikasi, dan tanggung jawabnya.
- Gunakan kalibrasi antarpengamat pada tugas berisiko tinggi.

Rubrik ini adalah kompas percakapan belajar. Ia membantu kita menyebutkan apa yang sudah tumbuh dan apa yang perlu dilatih---bukan mengecilkan pribadi menjadi sebuah angka.

== Tips Mendapatkan Hasil Belajar Terbaik
<tips-mendapatkan-hasil-belajar-terbaik>
Nilai yang baik patut diperjuangkan, tetapi nilai bukan harta karun terakhir. Hasil belajar terbaik terjadi ketika keterampilan yang dinilai di kelas mulai menolong Anda memahami diri, merawat relasi, menyelesaikan pekerjaan, dan memberi manfaat kepada orang lain.

=== Datang dengan Pengalaman Nyata
<datang-dengan-pengalaman-nyata>
Sebelum membaca sebuah bab atau memasuki kelas, ingatlah satu percakapan yang relevan. Catat apa yang terjadi, apa yang Anda rasakan, dan apa yang belum Anda pahami. Konsep akan lebih mudah melekat ketika memperoleh tempat dalam pengalaman.

Belajar melalui pengalaman bukan berarti pengalaman selalu benar. Pengalaman menyediakan bahan; refleksi, konsep, percobaan, dan umpan balik mengubahnya menjadi pembelajaran @kolb1984experiential.

=== Persiapkan Satu Langkah di Depan
<persiapkan-satu-langkah-di-depan>
Lakukan persiapan singkat tetapi teratur:

- baca tujuan belajar dan kata kunci;
- tandai satu gagasan yang menantang asumsi Anda;
- tulis satu pertanyaan yang sungguh ingin dijawab;
- siapkan satu kasus yang aman untuk dibahas; dan
- tentukan satu perilaku yang ingin diamati selama latihan.

Persiapan 15 menit yang terarah lebih berguna daripada membaca banyak halaman tanpa pertanyaan.

=== Berlatih Kecil dan Konsisten
<berlatih-kecil-dan-konsisten>
Komunikasi berkembang melalui pengulangan dalam situasi hidup. Latih satu perilaku selama beberapa hari: menunggu dua detik sebelum menjawab, mengajukan pertanyaan terbuka, merangkum sebelum berpendapat, atau mengonfirmasi siapa melakukan apa dan kapan.

Gunakan sasaran yang dapat diamati. "Menjadi pendengar yang lebih baik" sulit diuji; "merangkum pokok pikiran lawan bicara sebelum memberi saran dalam tiga percakapan minggu ini" lebih berguna.

=== Minta Umpan Balik yang Spesifik
<minta-umpan-balik-yang-spesifik>
Jangan hanya bertanya, "Bagaimana tadi?" Ajukan pertanyaan seperti:

- Pada bagian mana Anda merasa paling didengarkan?
- Kalimat mana yang terdengar tidak jelas atau menekan?
- Apa asumsi saya yang tampak dalam percakapan?
- Kapan perhatian atau minat Anda meningkat atau menurun?
- Satu hal apa yang sebaiknya saya lakukan berbeda?

Dengarkan umpan balik sampai selesai. Anda boleh meminta contoh dan konteks, tetapi jangan buru-buru membela niat. Dampak yang dirasakan orang lain merupakan data penting, walaupun bukan satu-satunya kebenaran.

=== Coba Kembali
<coba-kembali>
Umpan balik menjadi pembelajaran ketika mengubah tindakan. Pilih satu adegan, kalimat, atau keputusan; rancang alternatif; lalu ulangi. Simpan versi sebelum dan sesudah. Dengan cara itu, kemajuan tidak hanya terasa---ia terlihat.

=== Nilai Tindakan dan Relasi Bersamaan
<nilai-tindakan-dan-relasi-bersamaan>
Sesudah percakapan, tanyakan dua kelompok pertanyaan:

+ #strong[Tindakan:] Apakah pemahaman, keputusan, kesepakatan, atau pekerjaan bergerak maju?
+ #strong[Relasi:] Apakah kepercayaan, rasa aman, kejelasan, dan kesediaan bekerja kembali terpelihara?

Hasil cepat yang merusak kepercayaan sering menimbulkan biaya di kemudian hari. Sebaliknya, suasana hangat tanpa kejelasan dapat membiarkan persoalan tetap ada. Latihlah kemampuan menghasilkan nilai sambil menghormati pribadi.

=== Gunakan AI sebagai Cermin dan Pelatih
<gunakan-ai-sebagai-cermin-dan-pelatih>
AI dapat membantu menghasilkan skenario, menawarkan variasi pembuka, memeriksa keterbacaan, memainkan peran lawan bicara, atau mengajukan pertanyaan reflektif. Namun, jangan serahkan pengalaman, penilaian moral, persetujuan, dan tanggung jawab kepada mesin. Periksa fakta, bias, nada, serta dampak. Ungkapkan penggunaan AI sesuai ketentuan tugas dan Lampiran E.

=== Bangun Kebiasaan Portofolio
<bangun-kebiasaan-portofolio>
Jangan menunggu akhir semester. Seusai setiap tugas:

+ pilih bukti yang paling bermakna;
+ beri nama dan tanggal yang jelas;
+ catat umpan balik;
+ simpan versi perbaikan;
+ tulis refleksi tiga sampai lima kalimat; dan
+ periksa kembali privasi serta izin.

Portofolio yang dibangun sedikit demi sedikit akan lebih jujur dan kaya daripada portofolio yang dirakit tergesa-gesa.

=== Ketika Latihan Tidak Berhasil
<ketika-latihan-tidak-berhasil>
Kegagalan komunikasi bukan izin untuk menyalahkan diri atau pihak lain. Hentikan jika perlu, akui dampak, perbaiki fakta, minta maaf secara spesifik, dan sepakati tindak lanjut. Jika situasi menyangkut keselamatan, kekerasan, kesehatan mental, hukum, atau kuasa yang berat, carilah dukungan profesional atau institusional. Tugas kuliah tidak mengharuskan Anda menyelesaikan semua persoalan sendiri.

Gunakan pola pemulihan:

#quote(block: true)[
#strong[Akui apa yang terjadi → dengarkan dampak → ambil tanggung jawab → tanyakan kebutuhan → sepakati perbaikan → tindak lanjuti.]
]

=== Rencana Belajar Mingguan
<rencana-belajar-mingguan>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Waktu], [Kebiasaan], [Bukti kecil],),
  table.hline(),
  [Sebelum kelas], [membaca tujuan dan membawa satu kasus], [satu pertanyaan tertulis],
  [Saat kelas], [mencoba satu perilaku baru], [catatan pengamat],
  [Setelah kelas], [merefleksikan kejutan dan dampak], [jurnal 150 kata],
  [Dalam 48 jam], [meminta umpan balik atau mengulang adegan], [versi perbaikan],
  [Akhir minggu], [memilih artefak portofolio], [satu entri terkurasi],
)
=== Menjelang Pengumpulan
<menjelang-pengumpulan>
- Mulailah dari rubrik, bukan dari tampilan dokumen.
- Pastikan setiap klaim penting memiliki bukti.
- Periksa apakah perbaikan benar-benar tampak.
- Baca keras-keras bagian yang akan disampaikan.
- Pastikan kesepakatan memiliki pelaku, tindakan, waktu, dan cara meninjau.
- Tinjau sitasi, atribusi, persetujuan, privasi, dan catatan AI.
- Serahkan tepat waktu atau komunikasikan hambatan sebelum tenggat.

Anda tidak harus menjadi pembicara paling fasih di ruangan. Hadirlah sebagai pembelajar yang bersedia memperhatikan, mencoba, menerima koreksi, dan bertanggung jawab. Ketekunan semacam itulah yang mengubah latihan menjadi kemampuan.

== Pedoman Etika Komunikasi Berbantuan AI
<pedoman-etika-komunikasi-berbantuan-ai>
Kecerdasan buatan dapat memperluas repertoar komunikasi, tetapi tidak memiliki kehidupan, relasi, atau tanggung jawab moral seperti manusia. Karena itu, pertanyaan utamanya bukan hanya "Apakah AI dapat melakukannya?", melainkan "Apakah AI patut dilibatkan, dengan data apa, dalam peran apa, dan siapa yang bertanggung jawab?" Pedoman ini sejalan dengan penekanan pada pengawasan manusia, transparansi, privasi, keadilan, serta akuntabilitas dalam kerangka etika AI @unesco2021ethics@nist2023airmf.

=== Tujuh Prinsip
<tujuh-prinsip>
==== 1. Persetujuan dan Transparansi
<persetujuan-dan-transparansi>
Jelaskan keterlibatan AI apabila hal itu dapat memengaruhi kepercayaan, keputusan, hak, atau penilaian pihak lain. Jangan membuat seseorang percaya bahwa ia sedang berinteraksi sepenuhnya dengan manusia jika respons penting sebenarnya dihasilkan atau dikendalikan mesin.

==== 2. Privasi dan Minimalisasi Data
<privasi-dan-minimalisasi-data>
Masukkan data sesedikit mungkin. Hapus nama, identitas, rahasia organisasi, data kesehatan, data finansial, dan rincian intim. Persetujuan seseorang untuk berbicara dengan Anda bukan persetujuan untuk memasukkan perkataannya ke layanan AI.

==== 3. Batas Kewenangan
<batas-kewenangan>
AI dapat memberi alternatif, bukan mengambil alih keputusan yang menjadi kewenangan manusia. Jangan menggunakannya untuk berpura-pura sebagai dokter, konselor, pengacara, dosen penilai, atasan, atau pejabat yang berwenang.

==== 4. Pemeriksaan Fakta dan Bias
<pemeriksaan-fakta-dan-bias>
Periksa nama, angka, kutipan, sumber, aturan, dan klaim. Carilah siapa yang mungkin dirugikan oleh asumsi atau pola statistik. Keluaran yang lancar bukan jaminan bahwa isinya benar, adil, atau sesuai konteks.

==== 5. Larangan Manipulasi
<larangan-manipulasi>
Jangan memakai AI untuk mengeksploitasi ketakutan, kesepian, kedukaan, ketergantungan, usia, kondisi kesehatan, kesulitan ekonomi, atau ketidaktahuan seseorang. Personalisasi yang etis membantu orang memahami dan memilih; manipulasi menyembunyikan tujuan atau mempersempit kebebasan mereka.

==== 6. Kepemilikan Manusia
<kepemilikan-manusia>
Pesan yang menyatakan kasih, permintaan maaf, komitmen, evaluasi kinerja, keputusan bernilai tinggi, atau kabar yang mengubah hidup harus dimiliki manusia. AI boleh membantu persiapan, tetapi manusia perlu memahami, menyetujui, menyampaikan, serta menanggung dampaknya.

==== 7. Akuntabilitas
<akuntabilitas>
Pengguna tetap bertanggung jawab atas pesan dan tindakan yang dikirim atas namanya. Catat peran AI, verifikasi keluaran, sediakan jalan koreksi, dan tanggapi kerugian yang terjadi.

=== Memilih Peran AI
<memilih-peran-ai>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Peran], [Penggunaan yang patut], [Batas utama],),
  table.hline(),
  [#strong[Cermin]], [membantu menemukan asumsi, pola, atau pertanyaan reflektif], [tidak menentukan siapa diri Anda atau menilai pihak lain sebagai diagnosis],
  [#strong[Pelatih]], [membuat simulasi, memberi variasi, dan latihan respons], [umpan balik harus diuji pada manusia dan konteks nyata],
  [#strong[Penerjemah]], [membantu lintas bahasa atau tingkat keterbacaan], [makna, istilah budaya, dan kerahasiaan harus diperiksa],
  [#strong[Kopilot]], [menyusun alternatif, merangkum bahan yang diizinkan, atau memeriksa konsistensi], [manusia memilih, menyunting, memverifikasi, dan menyetujui hasil akhir],
  [#strong[Mediator pendukung]], [membantu memetakan kepentingan atau pilihan secara netral], [tidak menggantikan persetujuan, rasa aman, fasilitator manusia, atau mekanisme pengaduan],
  [#strong[Delegasi terbatas]], [menangani pesan rutin berisiko rendah dengan aturan dan pengawasan], [dilarang untuk relasi sensitif, keputusan bernilai tinggi, atau komunikasi yang memerlukan empati dan kewenangan manusia],
)
Semakin besar dampak dan semakin pribadi sebuah komunikasi, semakin kecil kewenangan yang layak didelegasikan.

=== Uji Sebelum Menggunakan AI
<uji-sebelum-menggunakan-ai>
Jawablah delapan pertanyaan berikut.

+ #strong[Tujuan:] nilai apa yang hendak diciptakan?
+ #strong[Kebutuhan:] apakah AI sungguh diperlukan?
+ #strong[Data:] data minimum apa yang dibutuhkan dan boleh digunakan?
+ #strong[Persetujuan:] siapa yang perlu mengetahui atau menyetujui?
+ #strong[Risiko:] siapa yang dapat dirugikan dan bagaimana?
+ #strong[Verifikasi:] sumber atau orang mana yang akan memeriksa hasil?
+ #strong[Kendali:] dapatkah manusia mengubah, menolak, atau menghentikan proses?
+ #strong[Tanggung jawab:] siapa yang akan menjawab jika terjadi kesalahan?

Jika satu jawaban penting belum jelas, tunda penggunaan AI.

=== Situasi yang Harus Tetap Dimiliki Manusia
<situasi-yang-harus-tetap-dimiliki-manusia>
- menyampaikan cinta, dukacita, penghargaan, atau permintaan maaf yang penting;
- memperoleh persetujuan dan menetapkan batas relasi;
- membuat keputusan penerimaan, penolakan, sanksi, nilai, pekerjaan, kredit, kesehatan, atau hukum;
- menangani krisis, ancaman keselamatan, kekerasan, dan kerentanan berat;
- memberikan evaluasi personal yang berdampak pada martabat atau masa depan;
- menandatangani komitmen dan kesepakatan; serta
- memediasi konflik ketika ada ketimpangan kuasa atau risiko pembalasan.

AI boleh membantu menyiapkan pertanyaan atau daftar periksa, tetapi kehadiran, penilaian, dan tanggung jawab tidak boleh dipalsukan.

=== Lampu Lalu Lintas Risiko
<lampu-lalu-lintas-risiko>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Tingkat], [Contoh], [Tindakan],),
  table.hline(),
  [#strong[Hijau]], [latihan presentasi dengan data rekaan; pemeriksaan tata bahasa teks nonrahasia], [gunakan dengan tinjauan biasa dan catat jika relevan],
  [#strong[Kuning]], [merangkum catatan rapat internal; menyusun pesan untuk konflik ringan; menerjemahkan pengalaman pribadi], [minimalkan data, peroleh izin, verifikasi, dan pastikan manusia menyunting],
  [#strong[Merah]], [mengunggah data rahasia; meniru suara tanpa izin; membuat keputusan hak seseorang; memanipulasi kerentanan; merespons krisis tanpa manusia], [jangan gunakan; pilih proses manusia atau sistem resmi yang berwenang],
)
=== Pemeriksaan Keluaran
<pemeriksaan-keluaran>
Sebelum memakai keluaran, periksa:

- #strong[Akurasi:] adakah klaim yang harus dibuktikan?
- #strong[Atribusi:] apakah gagasan, kutipan, gambar, dan data diberi sumber yang layak?
- #strong[Keadilan:] kelompok siapa yang tidak terlihat atau direpresentasikan secara stereotip?
- #strong[Nada:] apakah bahasa menghormati martabat dan sesuai dengan relasi?
- #strong[Pilihan:] apakah penerima memiliki ruang untuk bertanya, menolak, atau mengoreksi?
- #strong[Keamanan:] apakah data yang tidak perlu masih tertinggal?
- #strong[Kepemilikan:] apakah Anda memahami dan sungguh bersedia mengucapkan pesan itu?

=== Pernyataan Penggunaan AI
<pernyataan-penggunaan-ai>
Contoh pernyataan ringkas:

#quote(block: true)[
Saya menggunakan \[alat/model\] sebagai pelatih untuk menghasilkan tiga skenario keberatan dan memeriksa keterbacaan draf. Saya tidak memasukkan data identitas atau percakapan rahasia. Seluruh fakta diperiksa pada sumber yang dicantumkan; pilihan bahasa dan keputusan akhir saya tinjau serta pertanggungjawabkan sendiri.
]

Jika AI tidak digunakan, Anda dapat menyatakan demikian bila tugas mengharuskannya. Jangan mengada-adakan proses demi terlihat canggih.

=== Ketika Terjadi Kesalahan
<ketika-terjadi-kesalahan>
Hentikan penggunaan atau penyebaran, simpan bukti yang diperlukan secara aman, beri tahu pihak yang terdampak dan pihak berwenang sesuai konteks, koreksi informasi, hapus data jika patut, serta evaluasi penyebabnya. Jangan menjadikan "AI yang membuatnya" sebagai alasan untuk menghindari tanggung jawab.

Kaidah penutupnya sederhana:

#quote(block: true)[
#strong[Gunakan AI untuk memperbesar perhatian dan kemampuan manusia, bukan untuk mengecilkan pribadi, menyembunyikan tujuan, atau memindahkan tanggung jawab.]
]

#heading(level: 2, numbering: none)[Glosarium]
<glosarium>
Istilah dalam buku ini dipakai sebagai alat berpikir, bukan label untuk mengecilkan manusia. Padanan bahasa Inggris dicantumkan jika istilah tersebut sering muncul dalam literatur atau kerangka buku.

#strong[AI coach (pelatih AI).] Penggunaan AI untuk menyediakan skenario, latihan, pertanyaan, atau umpan balik awal; manusia tetap menguji saran pada konteks nyata.

#strong[AI mediator (mediator AI).] AI yang membantu memetakan isu, kepentingan, atau pilihan dalam konflik. Ia tidak menggantikan persetujuan, rasa aman, dan akuntabilitas mediator manusia.

#strong[Akuntabilitas.] Kesediaan menjelaskan dasar keputusan, memiliki dampak pesan, memperbaiki kesalahan, dan menerima konsekuensi yang patut.

#strong[Alih ragam (#emph[code-switching]).] Perpindahan bahasa, ragam, atau gaya sesuai konteks dan mitra komunikasi tanpa harus kehilangan makna dan nilai inti.

#strong[Attention (perhatian).] Tahap TAIDA ketika sasaran mulai memberi sumber daya mental kepada pesan karena merasakan relevansinya.

#strong[Audiens.] Pribadi atau kelompok yang menerima, menafsirkan, merespons, dan kadang ikut membentuk pesan publik; bukan wadah pasif.

#strong[Autentisitas.] Keselarasan yang dapat dipertanggungjawabkan antara nilai, peran, tujuan, bahasa, dan tindakan---bukan kebiasaan mengatakan segala sesuatu tanpa mempertimbangkan dampak.

#strong[Bias.] Kecenderungan sistematis dalam perhatian, penilaian, data, atau sistem yang dapat menghasilkan gambaran dan keputusan tidak seimbang.

#strong[Batas (#emph[boundary]).] Pernyataan mengenai apa yang bersedia dan tidak bersedia dilakukan seseorang untuk menjaga keselamatan, martabat, tanggung jawab, atau kesehatan relasi.

#strong[Capstone.] Kinerja puncak yang mengintegrasikan beragam kompetensi dalam satu persoalan autentik dan disertai bukti, umpan balik, perbaikan, serta refleksi.

#strong[Character (peran naratif).] Posisi atau sosok yang dijalankan seseorang dalam suatu kisah dan situasi---misalnya sahabat, pemimpin, ahli, pelanggan, warga, atau fasilitator.

#strong[Copilot (kopilot).] Peran AI yang mendampingi manusia dalam menyusun pilihan atau memeriksa pekerjaan, sementara manusia tetap memegang kendali dan keputusan akhir.

#strong[Coordinated action (tindakan terkoordinasi).] Tindakan beberapa pihak yang selaras karena tanggung jawab, urutan, waktu, sumber daya, dan cara peninjauannya telah dipahami.

#strong[Data minimal.] Jumlah dan jenis data paling sedikit yang benar-benar diperlukan untuk mencapai tujuan yang sah.

#strong[Delegate (delegasi AI).] Pelimpahan tugas tertentu kepada sistem AI berdasarkan lingkup, aturan, pengawasan, serta jalan penghentian yang jelas; hanya patut untuk tugas berisiko rendah dan terbatas.

#strong[Desire (keinginan).] Tahap TAIDA ketika seseorang melihat nilai suatu hasil dan mulai mempertimbangkan pilihan, pengorbanan, serta risiko untuk mewujudkannya.

#strong[Domain komunikasi.] Lingkar konteks tempat komunikasi terjadi, seperti diri, keluarga, persahabatan, pekerjaan, pelanggan, komunitas, dan publik.

#strong[Empati.] Upaya memahami pengalaman dari kerangka acuan orang lain sambil tetap membedakan pengalamannya dari pengalaman kita.

#strong[Episode relasi.] Satuan peristiwa komunikasi yang memiliki konteks, urutan tindakan dan respons, serta dampak pada keadaan relasi.

#strong[Fakta.] Pernyataan tentang peristiwa atau keadaan yang dapat diperiksa melalui pengamatan atau sumber; berbeda dari tafsiran dan opini.

#strong[Generative AI (AI generatif).] Sistem yang menghasilkan teks, gambar, suara, kode, atau bentuk lain berdasarkan pola data dan instruksi, tanpa menjamin kebenaran atau kepatutan keluarannya.

#strong[Interest (minat).] Tahap TAIDA ketika perhatian berkembang menjadi keterlibatan karena sasaran melihat hubungan pesan dengan masalah, kebutuhan, atau aspirasinya.

#strong[Kesepakatan (#emph[agreement]).] Pemahaman bersama yang cukup jelas dan sukarela mengenai tujuan, tindakan, tanggung jawab, batas, waktu, atau cara meninjau kembali.

#strong[Kepentingan (#emph[interest] dalam negosiasi).] Kebutuhan, kekhawatiran, nilai, atau alasan yang mendasari posisi yang dinyatakan pihak.

#strong[Kepribadian (#emph[personality]).] Pola kecenderungan berpikir, merasa, dan bertindak yang relatif menetap, tetapi tetap dipengaruhi konteks dan tidak menentukan seluruh pribadi.

#strong[Keadaan relasi (#emph[relationship state]).] Kondisi hubungan pada suatu waktu, antara lain tingkat kepercayaan, rasa aman, kejelasan, keterikatan, dan kemampuan bekerja kembali.

#strong[Kinerja autentik.] Demonstrasi kompetensi dalam situasi yang memiliki tujuan, ketidakpastian, respons nyata, dan konsekuensi bermakna.

#strong[Komunikasi asertif.] Penyampaian pengamatan, perasaan, kebutuhan, batas, atau permintaan secara jelas dengan tetap menghormati hak dan pilihan pihak lain.

#strong[Konteks runtuh (#emph[context collapse]).] Bertemunya berbagai audiens dan norma dalam satu ruang komunikasi, terutama media digital, sehingga pesan yang dimaksudkan untuk satu kelompok dibaca kelompok lain.

#strong[Language (bahasa).] Sistem tanda verbal, visual, gestural, atau multimodal yang dipakai untuk membentuk dan menegosiasikan makna.

#strong[Makna.] Pemahaman yang dibangun melalui hubungan antara pesan, pengalaman, konteks, dan interpretasi; tidak sekadar berada di dalam kata-kata.

#strong[Mendengarkan aktif.] Perhatian yang ditunjukkan melalui keheningan yang tepat, pertanyaan, rangkuman, pemeriksaan pemahaman, dan respons terhadap isi maupun emosi.

#strong[Narasi.] Susunan peristiwa, tokoh, tujuan, konflik, dan perubahan yang memberi bentuk serta makna pada pengalaman.

#strong[Objective (tujuan).] Perubahan yang hendak diwujudkan melalui komunikasi pada pemahaman, keadaan, keputusan, tindakan, atau relasi.

#strong[Opini.] Penilaian atau pendirian yang perlu dibedakan dari fakta serta terbuka untuk diberi alasan, diuji, dan direvisi.

#strong[Otonomi.] Kemampuan dan hak seseorang untuk memahami pilihan serta memutuskan tanpa paksaan atau manipulasi yang tidak patut.

#strong[Person (pribadi).] Manusia utuh dengan sejarah, nilai, relasi, kerentanan, kebebasan, dan kemungkinan bertumbuh; selalu lebih luas daripada pesan, data, peran, atau profilnya.

#strong[Persona publik.] Cara seseorang menampilkan identitas dan peran di hadapan audiens; dapat terkurasi, tetapi seharusnya tidak menipu tentang hal yang material.

#strong[Persetujuan (#emph[consent]).] Kesediaan yang diberikan secara sadar, spesifik, cukup informasi, dan tanpa tekanan; dapat ditarik kembali.

#strong[Portofolio komunikasi.] Kumpulan artefak terpilih yang menunjukkan konteks, kinerja, bukti, umpan balik, perbaikan, refleksi, dan perkembangan kompetensi.

#strong[Posisi.] Tuntutan atau pilihan yang dinyatakan dalam negosiasi; satu posisi dapat berakar pada beberapa kepentingan.

#strong[Profiling.] Pengelompokan atau penyimpulan karakteristik seseorang dari data untuk memprediksi perilaku; perlu dibatasi agar tidak berubah menjadi stereotip atau diskriminasi.

#strong[Publik.] Ruang dan himpunan orang yang terbentuk di sekitar isu bersama, tempat pesan dapat beredar melampaui audiens yang dibayangkan.

#strong[Refleksi dalam tindakan.] Kemampuan memperhatikan kejutan dan menyesuaikan keputusan ketika sedang bertindak, bukan hanya sesudah peristiwa selesai.

#strong[Relasi.] Pola keterhubungan yang berkembang melalui sejarah interaksi, harapan, kepercayaan, kuasa, komitmen, dan tindakan bersama.

#strong[Repertoire (repertoar).] Kumpulan cara komunikasi yang dapat dipilih, seperti bertanya, mendengarkan, bercerita, menjelaskan konsep, menyajikan data, menggunakan visual, bernegosiasi, atau berdiam dengan penuh perhatian.

#strong[Respons.] Tanggapan verbal, nonverbal, tindakan, keheningan, atau perubahan keadaan yang memberi informasi tentang bagaimana komunikasi diterima.

#strong[Sasaran (#emph[target]).] Pribadi atau kelompok yang ingin dipahami dan dilayani dalam TAIDA; bukan objek yang boleh dikendalikan.

#strong[Stakeholder (pemangku kepentingan).] Pihak yang memengaruhi, dipengaruhi, memiliki hak, atau menanggung manfaat dan risiko dari suatu keputusan.

#strong[TAIDA.] Rute komunikasi #strong[Target--Attention--Interest--Desire--Action] yang membantu komunikator mengenali sasaran, membaca keadaan, menciptakan relevansi dan nilai, serta memfasilitasi tindakan secara etis.

#strong[Tafsir.] Makna atau cerita yang ditarik dari fakta; perlu diperiksa karena orang dapat menafsirkan peristiwa yang sama secara berbeda.

#strong[Tindakan (#emph[action]).] Tahap TAIDA ketika nilai diterjemahkan menjadi langkah nyata, keputusan, percobaan, komitmen, atau penolakan yang jelas.

#strong[Transparansi AI.] Keterbukaan yang proporsional mengenai keterlibatan AI, data, batas, dan tinjauan manusia ketika hal itu relevan bagi kepercayaan atau keputusan.

#strong[Umpan balik.] Informasi spesifik tentang perilaku dan dampaknya yang digunakan untuk mempertahankan kekuatan atau memperbaiki tindakan berikutnya.

#strong[Validasi.] Pengakuan bahwa pengalaman atau emosi seseorang dapat dipahami dalam konteksnya; tidak selalu berarti menyetujui semua tafsir atau tindakan.

#strong[Value (nilai/manfaat).] Perbaikan keadaan yang dianggap bermakna oleh pihak terkait dan diciptakan melalui pemahaman, pilihan, pelayanan, atau tindakan bersama.

#heading(level: 2, numbering: none)[Daftar Pustaka]
<daftar-pustaka>
Rujukan buku ini menjembatani pengalaman komunikasi dengan teori dan praktik. Untuk pembacaan lanjutan, sumber-sumbernya dapat dikelompokkan sebagai berikut.

- #strong[Pribadi, identitas, dan narasi:] Goffman, McAdams, Rogers, Dweck, serta Langi.
- #strong[Empati, bahasa, dan mendengarkan:] Rosenberg, Clark dan Brennan, serta Schein.
- #strong[Pesan, persuasi, dan penciptaan nilai:] Heath dan Heath, Drucker, serta Vargo dan Lusch.
- #strong[Negosiasi, organisasi, dan komunitas:] Fisher, Ury, dan Patton; Edmondson; Freeman; Locke dan Latham; Ostrom; serta Putnam.
- #strong[Komunikasi publik dan konteks digital:] Marwick dan boyd.
- #strong[Belajar dari pengalaman:] Kolb dan Schön.
- #strong[Etika serta tata kelola AI:] UNESCO, NIST, serta Floridi dan rekan-rekan.

Daftar berikut memuat seluruh rujukan yang digunakan dalam buku.

#block[
] <refs>
#heading(level: 2, numbering: none)[Tentang Penulis]
<tentang-penulis>
#strong[Armein Z. R. Langi] adalah lulusan Teknik Elektro Institut Teknologi Bandung (ITB). Ia menyelesaikan studinya pada Oktober 1987 dan menjadi dosen ITB pada Desember tahun yang sama. Pada April 1988, ia bergabung dengan PAU Mikroelektronika sebagai staf Dr.~Richard Mengko. Prof.~Samaun kemudian menominasikannya untuk studi lanjut melalui program World Bank XVII.

Jalan menuju studi lanjut tidak berlangsung lurus. Armein memasuki kamp bahasa Inggris WUSC di Universitas Gadjah Mada pada Januari 1989 dengan nilai TOEFL terendah dan nyaris tidak diterima. Ia mencurahkan waktunya untuk belajar hingga meraih nilai tertinggi dan dipercaya menyampaikan pidato penutupan di hadapan Direktur Jenderal Pendidikan Tinggi. Pada saat yang sama, tujuh surat penolakan dari universitas telah datang. Dengan dukungan WUSC, reputasi yang lebih dahulu dirintis Budi Rahardjo, dan kesediaan Prof.~Witold Kinsner menerimanya di University of Manitoba, satu surat penerimaan akhirnya tiba @langi2025dayatarik.

Di balik perjalanan akademik itu terdapat keputusan relasional yang membentuk cara pandangnya. Ketika putri pertamanya, Gladys, diperkirakan lahir pada September 1989, ia menunda keberangkatan agar dapat mendampingi istrinya, Ina. Setelah kelahiran Gladys, Armein berangkat dan menjejakkan kaki di Los Angeles pada 13 Desember 1989---tercapainya impian yang telah ia simpan sejak duduk di kelas dua sekolah dasar di Tomohon. Impian itu bermula dari kartu-kartu pos yang dikirim ayahnya, William Langi, ketika belajar di San Anselmo dekat San Francisco. Tujuh tahun kemudian, setelah tugas belajarnya selesai, ia kembali melalui Los Angeles bersama Ina serta ketiga anak mereka, Gladys, Kezia, dan Andria.

Pengalaman tersebut memperlihatkan tema yang terus hadir dalam karya dan pengajarannya: impian membutuhkan ketekunan, pencapaian memperoleh makna melalui relasi, dan pengalaman hidup dapat diolah menjadi pesan yang menolong orang lain. Dalam #emph[Daya Tarik: Melalui Pesan Verbal dan Nonverbal], yang diselesaikan di Bandung pada 17 April 2025, ia menulis terutama bagi mahasiswa II-2111 Komunikasi Interpersonal dan bagi pembaca yang ingin bertumbuh dalam kehidupan pribadi, profesional, serta kemasyarakatan. Baginya, daya tarik yang bertahan tidak berhenti pada kemasan; ia tumbuh melalui kepribadian, kisah yang bermakna, konsep yang mencerdaskan, opini yang bertanggung jawab, serta cara verbal dan nonverbal yang selaras.

Buku #emph[Komunikasi Interpersonal dan Publik] melanjutkan kepedulian itu. Armein hadir bukan sebagai petualang yang mengaku menempuh jalan tanpa kesulitan, melainkan sebagai pendidik yang pernah belajar dari keterbatasan, penolakan, pertolongan, keluarga, dan kesempatan kedua. Ia mengajak mahasiswa menemukan "harta karun" komunikasi: kemampuan menciptakan tindakan yang bernilai, memelihara relasi yang sehat, dan tetap bertanggung jawab atas cara keduanya dicapai.

#quote(block: true)[
#emph[Kita mungkin mulai belajar komunikasi karena ingin tampil lebih menarik atau lebih berhasil. Dalam perjalanan, kita menemukan sesuatu yang lebih berharga: kemampuan melihat manusia sebagai pribadi, mendengarkan dengan sungguh-sungguh, serta membangun kehidupan bersama melalui kata dan tindakan yang dapat dipercaya.]
]

#bibliography(("references.bib"))

