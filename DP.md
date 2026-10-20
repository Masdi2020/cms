# Kelompok 3 Kalimantan Bio
1. Wisnu
2. Abbie
3. Nabilah
4. Dylan
5. Chrisella

QnA:
Wanda : Apakah bisa closure dalam closure, karekan kan kalau python kan bisa lambda dalam lambda?
A : Harusnya bisa, tapi dari kami belum bisa coba. Bikin pake AntiGravity AI

Jayen : Masih kurang paham lifetime ('a), bisa jelasin gak?
A : (Hasil AI) nyari referensi yang bakal digabung, petik A itu bakal nyari value yang ada.

Dimas : Gimana caranya milih Fn, FnMut dan FnOnce? Dan apa yang bakal terjadi kalau salah pake?
A : Diliat dari pola kodenya, karena di kodenya kita gak definisikan langsung traitnya

# Kelompok 1 Kalimantan Bio
1. Farel Alkayis
2. Alisya Duri
3. Rayhant Al munawar
4. Thisya Darmala
5. Veronika

Dimas : Jelaskan perbedaan iter, iter_mut, dan into_iter dari segi ownershipnya?
A : iter itu dia cuma minjem kepemilikan; kalau iter_mut, selagi dia bisa diubah, dia bakal dipinjem; dan kalau into_iter bakal memindahkan kepemilikan seluruhnya

Dimas : Apa pengaruhnya lazy evaluation ke fungsi yang ada di rust?
A : Jadi fungsinya bakal ngambil sesuai yang diminta, gak semuanya. Jadi lebih hemat memori

Dimas : Kalau misalnya kalian punya jutaan data, lebih baik iterator atau for loop?
A : Lebih baik pakai iter, karena lebih efisien dibandingkan for loop. Kalau pake for loop dia bakal ngejalanin sampe batas akhirnya.

# Kelompok 1 Smart Sail IoT
1. Nabil
2. Nastain
3. Khairullah

Dimas : Mengapa sebuah closure yang mengubah variabel dari lingkungan sekitarnya tidak selalu dapat digunakan pada fungsi yang mensyaratkan trait Fn?
A : Aturan peminjaman memori closure

Dylan : Gimana cara kerja move?
A : Dia bakal memindahkan sebuah data dari data sebelumnya ke sesudahnya, dan gak bisa dipanggil lagi setelahnya

Dimas : Apa sisi negatif dari penggunaan closures?
A : Jika terlalu banyak digunakan bakal bertabrakan antar closures nya. Nambah beban memori untuk baca sekitar lingkungannya