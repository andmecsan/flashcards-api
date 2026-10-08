# Frontera central de permisos de la API. Cada recurso tiene su policy, y
# `Api::V1::BaseController` exige autorizar cada acción (ver `verify_authorized`).
#
# Regla base: un recurso solo lo gestiona su propietario. `user` es el usuario
# autenticado (puede ser nil en pruebas de acceso anónimo) y `record`, el recurso.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Propietario del recurso: lo define el modelo con `#owner`.
  def owner?
    user.present? && record.respond_to?(:owner) && record.owner == user
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "#{self.class} debe definir #resolve"
    end
  end
end
