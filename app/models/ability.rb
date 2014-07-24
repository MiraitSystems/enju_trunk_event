class Ability
  def initialize_event(user, ip_address = nil)
    case user.try(:role).try(:name)
    when 'Administrator'
      can [:read, :new, :create], EventCategory
      can [:edit, :update, :destroy], EventCategory do |event_category|
        !['unknown', 'closed'].include?(event_category.name)
      end
      can :manage, [
        Event,
        EventImportFile,
        Participate
      ]
      can :read, EventImportResult
    when 'Librarian'
      can [:read, :new, :create], EventCategory
      can [:edit, :update, :destroy], EventCategory do |event_category|
        !['unknown', 'closed'].include?(event_category.name)
      end
      can :manage, [
        Event,
        EventImportFile,
        Participate
      ]
      can :read, EventImportResult
    when 'User'
      can :read, [
        Event,
        EventCategory
      ]
    else
      can :read, [
        Event,
        EventCategory
      ]
    end
  end
end
