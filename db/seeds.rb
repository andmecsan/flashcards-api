# db/seeds.rb

puts "🌱 Creando datos de demo..."

# Usuario demo
user = User.find_by(email: "flashcardsupport@gmail.com")

unless user
  puts "❌ No hay usuario con ese email. Inicia sesión con Google primero con flashcardsupport@gmail.com"
  exit
end

puts "✅ Usuario: #{user.name}"

# Mazo 1: Chino HSK-1
chino = user.decks.find_or_create_by!(name: "Chino HSK-1") do |d|
  d.icon = "🇨🇳"
  d.color = "#EF4444"
end

vocab = chino.categories.find_or_create_by!(name: "Vocabulario básico")

[
  ["你好", "Hola (nǐ hǎo)"],
  ["谢谢", "Gracias (xiè xie)"],
  ["再见", "Adiós (zài jiàn)"],
  ["对不起", "Lo siento (duì bu qǐ)"],
  ["不客气", "De nada (bú kè qi)"],
  ["爸爸", "Papá (bà ba)"],
  ["妈妈", "Mamá (mā ma)"],
  ["朋友", "Amigo (péng you)"],
  ["学生", "Estudiante (xué shēng)"],
  ["老师", "Profesor (lǎo shī)"],
].each do |front, back|
  vocab.cards.find_or_create_by!(front: front) { |c| c.back = back }
end

numeros = chino.categories.find_or_create_by!(name: "Números")

[
  ["一", "Uno (yī)"],
  ["二", "Dos (èr)"],
  ["三", "Tres (sān)"],
  ["四", "Cuatro (sì)"],
  ["五", "Cinco (wǔ)"],
  ["六", "Seis (liù)"],
  ["七", "Siete (qī)"],
  ["八", "Ocho (bā)"],
  ["九", "Nueve (jiǔ)"],
  ["十", "Diez (shí)"],
].each do |front, back|
  numeros.cards.find_or_create_by!(front: front) { |c| c.back = back }
end

puts "✅ Mazo: #{chino.name} (#{chino.cards.count} tarjetas)"

# Mazo 2: Algoritmos
algo = user.decks.find_or_create_by!(name: "Algoritmos") do |d|
  d.icon = "🧮"
  d.color = "#7C3AED"
end

complejidad = algo.categories.find_or_create_by!(name: "Complejidad")

[
  ["¿Qué es O(1)?", "Complejidad constante — el tiempo no depende del tamaño de la entrada"],
  ["¿Qué es O(n)?", "Complejidad lineal — el tiempo crece proporcionalmente al tamaño de la entrada"],
  ["¿Qué es O(log n)?", "Complejidad logarítmica — el tiempo crece logarítmicamente (ej: búsqueda binaria)"],
  ["¿Qué es O(n²)?", "Complejidad cuadrática — el tiempo crece con el cuadrado de la entrada (ej: bubble sort)"],
  ["¿Qué es O(n log n)?", "Complejidad lineal-logarítmica — típica de algoritmos de ordenación eficientes (merge sort, quick sort)"],
].each do |front, back|
  complejidad.cards.find_or_create_by!(front: front) { |c| c.back = back }
end

estructuras = algo.categories.find_or_create_by!(name: "Estructuras de datos")

[
  ["¿Qué es un array?", "Colección de elementos en posiciones contiguas de memoria, acceso O(1) por índice"],
  ["¿Qué es una lista enlazada?", "Colección de nodos donde cada uno apunta al siguiente, inserción O(1) pero acceso O(n)"],
  ["¿Qué es una pila (stack)?", "Estructura LIFO (Last In First Out) — push y pop en O(1)"],
  ["¿Qué es una cola (queue)?", "Estructura FIFO (First In First Out) — enqueue y dequeue en O(1)"],
  ["¿Qué es un árbol binario?", "Estructura jerárquica donde cada nodo tiene como máximo dos hijos"],
].each do |front, back|
  estructuras.cards.find_or_create_by!(front: front) { |c| c.back = back }
end

puts "✅ Mazo: #{algo.name} (#{algo.cards.count} tarjetas)"

# Simular historial de estudio para que las stats tengan datos
puts "📊 Simulando historial de estudio..."

vocab.cards.limit(6).each do |card|
  review = card.review_for(user)
  review.save! unless review.persisted?
  review.apply_review!(5)
end

vocab.cards.offset(6).each do |card|
  review = card.review_for(user)
  review.save! unless review.persisted?
  review.apply_review!(3)
end

numeros.cards.limit(3).each do |card|
  review = card.review_for(user)
  review.save! unless review.persisted?
  review.apply_review!(4)
end

complejidad.cards.limit(2).each do |card|
  review = card.review_for(user)
  review.save! unless review.persisted?
  review.apply_review!(5)
end

puts "✅ Reviews simulados"
puts ""
puts "🎉 Seeds completados!"
puts "   Mazos: #{user.decks.count}"
puts "   Categorías: #{Category.where(deck: user.decks).count}"
puts "   Tarjetas: #{user.decks.sum { |d| d.cards.count }}"
puts "   Reviews: #{CardReview.where(user: user).count}"
puts "   Logs: #{ReviewLog.joins(:card_review).where(card_reviews: { user: user }).count}"