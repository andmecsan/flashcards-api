# Etiquetas: las predefinidas (área, nivel, curso) las puede leer cualquier
# usuario autenticado y nadie las modifica desde la API; las personales solo
# las gestiona su dueño.
class TagPolicy < ApplicationPolicy
  def index?   = user.present?
  def system?  = user.present?
  def update?  = own_personal?
  def destroy? = own_personal?
  def merge?   = own_personal?

  class Scope < ApplicationPolicy::Scope
    # Etiquetas personales del usuario.
    def resolve
      return scope.none if user.blank?

      scope.personal.where(user_id: user.id)
    end
  end

  private

  def own_personal?
    user.present? && record.personal? && record.user_id == user.id
  end
end
