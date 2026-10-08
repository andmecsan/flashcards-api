# Temarios: solo los ve y gestiona el propietario de su asignatura.
class CategoryPolicy < ApplicationPolicy
  def index?        = user.present?
  def create?       = owner?
  def show?         = owner?
  def update?       = owner?
  def destroy?      = owner?
  def update_topic? = owner?
  def review_cards? = owner?
  def move?         = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?

      scope.joins(:deck).where(decks: { user_id: user.id })
    end
  end
end
