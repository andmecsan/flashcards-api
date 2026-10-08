# Asignaturas: solo las ve y gestiona su propietario.
class DeckPolicy < ApplicationPolicy
  def index?        = user.present?
  def create?       = owner?
  def show?         = owner?
  def update?       = owner?
  def destroy?      = owner?
  def study?        = owner?
  def stats?        = owner?
  def create_topic? = owner?
  def favorite?     = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?

      scope.where(user_id: user.id)
    end
  end
end
