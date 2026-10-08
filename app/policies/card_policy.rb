# Tarjetas: solo las ve y gestiona el propietario de su asignatura.
# `generate?` no depende de ninguna tarjeta: basta con estar autenticado.
class CardPolicy < ApplicationPolicy
  def index?    = user.present?
  def create?   = owner?
  def show?     = owner?
  def update?   = owner?
  def destroy?  = owner?
  def review?   = owner?
  def generate? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?

      scope.joins(category: :deck).where(decks: { user_id: user.id })
    end
  end
end
