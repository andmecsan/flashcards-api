FactoryBot.define do
  factory :user do
    name { "Andrea" }
    email { "andrea@test.com" }
    uid { SecureRandom.uuid }
  end

  factory :deck do
    association :user
    name { "Algoritmos" }
    description { "Tarjetas de algoritmia" }
  end

  factory :card do
    association :deck
    front { "¿Qué es SM-2?" }
    back { "Un algoritmo de repaso espaciado" }
  end
end